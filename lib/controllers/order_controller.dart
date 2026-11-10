import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/services/bakong_service.dart';
import 'package:my_api/utils/hash_utils.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';
import 'cart_controller.dart';

class OrderService {
  static Future<Map<String, dynamic>> checkout({
    required String userId,
    String? addressId,
    Map<String, dynamic>? newAddress,
    String? paymentMethodId,
    String paymentType = 'card',
    String? voucherCode,
    bool useLoyaltyPoints = false,
  }) async {
    await Database.ensureConnected();
    final cart = await CartService.getCart(userId);
    final rawItems = cart['items'];
    final items = (rawItems is List)
        ? rawItems
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    if (items.isEmpty) {
      throw const HttpException('Cart is empty. Cannot checkout.');
    }

    // 1. Validate & reduce inventory
    for (final it in items) {
      final pid = it['productId']?.toString();
      final qty = parseInt(it['quantity'], 1);
      final product = await Database.products.findOne(where.eq('_id', parseId(pid)));
      if (product == null) {
        throw HttpException('Product ${it['name']} not found.');
      }
      final stock = parseInt(product['stock'], 0);
      if (stock < qty) {
        throw HttpException('Insufficient stock for ${it['name']}. Only $stock left.');
      }
      // Decrement stock
      await Database.products.updateOne(
        where.eq('_id', parseId(pid)),
        modify.inc('stock', -qty),
      );
    }

    // 2. Resolve Shipping Address
    Map<String, dynamic>? shippingAddress;
    if (addressId != null) {
      final addr = await Database.addresses.findOne(where.eq('_id', parseId(addressId)));
      if (addr != null) shippingAddress = cleanDoc(addr);
    } else if (newAddress != null) {
      shippingAddress = newAddress;
    } else {
      final defaultAddr = await Database.addresses.findOne(
        where.eq('userId', userId).eq('isDefault', true),
      );
      if (defaultAddr != null) shippingAddress = cleanDoc(defaultAddr);
    }

    // 3. Calculate discounts
    double subtotal = parseDouble(cart['subtotal']);
    double discount = 0.0;

    if (voucherCode != null && voucherCode.trim().isNotEmpty) {
      final v = await Database.vouchers.findOne(
        where.eq('code', voucherCode.trim().toUpperCase()).eq('isActive', true),
      );
      if (v != null) {
        final minSpend = parseDouble(v['minSpend']);
        if (subtotal >= minSpend) {
          final type = v['discountType']?.toString() ?? 'percentage';
          final val = parseDouble(v['discountValue']);
          if (type == 'percentage') {
            discount += subtotal * (val / 100);
            final maxDisc = parseDouble(v['maxDiscount']);
            if (maxDisc > 0 && discount > maxDisc) discount = maxDisc;
          } else {
            discount += val;
          }
        }
      }
    }

    // Loyalty points deduction (100 points = $5 discount)
    double pointsDiscount = 0.0;
    if (useLoyaltyPoints) {
      final user = await Database.users.findOne(where.eq('_id', parseId(userId)));
      final points = parseInt(user?['loyaltyPoints'], 0);
      if (points >= 100) {
        final usableChunks = (points ~/ 100);
        pointsDiscount = (usableChunks * 5).toDouble();
        if (pointsDiscount > (subtotal - discount)) {
          pointsDiscount = (subtotal - discount).clamp(0, 9999);
        }
        await Database.users.updateOne(
          where.eq('_id', parseId(userId)),
          modify.inc('loyaltyPoints', -(usableChunks * 100)),
        );
      }
    }

    discount += pointsDiscount;
    discount = double.parse(discount.toStringAsFixed(2));

    const shipping = 0.0;
    final total = double.parse((subtotal - discount + shipping).clamp(0, 999999).toStringAsFixed(2));

    final now = DateTime.now().toUtc();
    final orderId = ObjectId();
    final orderNumber = 'ORD-${now.year}${HashUtils.generateNumericOtp(6)}';

    final isBakong = paymentType == 'bakong' || paymentType == 'khqr';
    Map<String, dynamic>? bakongData;
    if (isBakong) {
      final useKhr = BakongService.defaultCurrency == 'KHR';
      final rawKhr = (total * 4100).round();
      final khqrAmount = useKhr
          ? (rawKhr < 100 && rawKhr > 0 ? 100.0 : rawKhr.toDouble())
          : total;
      bakongData = await BakongService.createKhqrPayment(
        amount: khqrAmount,
        currency: useKhr ? 'KHR' : 'USD',
        billNumber: orderNumber,
        storeLabel: 'Store Purchase',
      );
    }

    final orderDoc = {
      '_id': orderId,
      'orderNumber': orderNumber,
      'userId': userId,
      'items': items,
      'shippingAddress': shippingAddress ?? {'street': 'Standard Delivery'},
      'paymentMethod': {
        'type': paymentType,
        'paymentMethodId': paymentMethodId,
        'status': isBakong ? 'pending' : 'paid',
        if (bakongData != null) 'khqr': bakongData,
      },
      'subtotal': subtotal,
      'discount': discount,
      'shipping': shipping,
      'total': total,
      'status': isBakong ? 'pending_payment' : 'processing',
      'tracking': [
        {
          'status': 'order_placed',
          'title': 'Order Placed',
          'description': 'Your order has been received and confirmed.',
          'timestamp': now.toIso8601String(),
          'completed': true,
        },
        {
          'status': 'processing',
          'title': 'Processing',
          'description': 'Seller is preparing your package.',
          'timestamp': now.add(const Duration(hours: 1)).toIso8601String(),
          'completed': !isBakong,
        },
        {
          'status': 'shipped',
          'title': 'On the Way',
          'description': 'Carrier picked up your order.',
          'timestamp': null,
          'completed': false,
        },
        {
          'status': 'delivered',
          'title': 'Delivered',
          'description': 'Package delivered to recipient.',
          'timestamp': null,
          'completed': false,
        },
      ],
      'createdAt': now,
      'updatedAt': now,
    };

    await Database.orders.insertOne(orderDoc);

    // Award loyalty points for purchase ($1 = 1 point)
    final pointsEarned = total.floor();
    await Database.users.updateOne(
      where.eq('_id', parseId(userId)),
      modify.inc('loyaltyPoints', pointsEarned),
    );

    // Clear cart
    await CartService.clearCart(userId);

    // Push notification
    await Database.notifications.insertOne({
      '_id': ObjectId(),
      'userId': userId,
      'title': isBakong ? 'Order Placed - Pending Payment' : 'Order Confirmed! ',
      'body': isBakong
          ? 'Scan the Bakong KHQR code to complete payment for order #$orderNumber'
          : 'Your order #$orderNumber has been placed successfully.',
      'type': 'order',
      'orderId': orderId.oid,
      'isRead': false,
      'createdAt': now,
    });

    final cleaned = cleanDoc(orderDoc)!;
    if (bakongData != null) {
      cleaned['khqr'] = bakongData;
    }
    return cleaned;
  }

  static Future<List<Map<String, dynamic>>> listOrders(String userId, {String? status}) async {
    var selector = where.eq('userId', userId);
    if (status != null && status.isNotEmpty && status != 'all') {
      selector = selector.eq('status', status);
    }
    final docs = await Database.orders.find(selector.sortBy('createdAt', descending: true)).toList();
    return cleanDocs(docs);
  }

  static Future<Map<String, dynamic>?> getOrder(String userId, String orderId) async {
    final parsed = parseId(orderId);
    Map<String, dynamic>? doc;
    if (parsed is ObjectId) {
      doc = await Database.orders.findOne(where.eq('userId', userId).eq('_id', parsed));
    }
    doc ??= await Database.orders.findOne(where.eq('userId', userId).eq('orderNumber', orderId));
    return cleanDoc(doc);
  }

  static Future<Map<String, dynamic>> cancelOrder(String userId, String orderId) async {
    final order = await getOrder(userId, orderId);
    if (order == null) throw const HttpException('Order not found');

    if (order['status'] != 'processing' && order['status'] != 'pending') {
      throw HttpException('Order cannot be cancelled in state: ${order['status']}');
    }

    // Restore inventory
    final items = (order['items'] as List?) ?? [];
    for (final it in items) {
      if (it is Map) {
        final pid = it['productId']?.toString();
        final qty = parseInt(it['quantity'], 1);
        if (pid != null) {
          await Database.products.updateOne(where.eq('_id', parseId(pid)), modify.inc('stock', qty));
        }
      }
    }

    await Database.orders.updateOne(
      where.eq('_id', parseId(order['id'] ?? order['_id'])),
      modify.set('status', 'cancelled').set('updatedAt', DateTime.now().toUtc()),
    );

    return (await getOrder(userId, orderId))!;
  }

  static Future<Map<String, dynamic>> returnOrder({
    required String userId,
    required String orderId,
    required String reason,
    List<dynamic>? items,
    String? notes,
  }) async {
    final order = await getOrder(userId, orderId);
    if (order == null) throw const HttpException('Order not found');

    await Database.orders.updateOne(
      where.eq('_id', parseId(order['id'] ?? order['_id'])),
      modify.set('status', 'return_requested').set('returnDetails', {
        'reason': reason,
        'items': items ?? order['items'],
        'notes': notes,
        'requestedAt': DateTime.now().toUtc().toIso8601String(),
      }).set('updatedAt', DateTime.now().toUtc()),
    );

    return (await getOrder(userId, orderId))!;
  }

  static Future<Map<String, dynamic>> verifyBakongPayment(String orderNumberOrMd5) async {
    await Database.ensureConnected();
    var order = await Database.orders.findOne(
      where.eq('orderNumber', orderNumberOrMd5),
    );
    order ??= await Database.orders.findOne(
      where.eq('paymentMethod.khqr.md5', orderNumberOrMd5),
    );
    if (order == null) {
      final parsed = parseId(orderNumberOrMd5);
      if (parsed is ObjectId) {
        order = await Database.orders.findOne(where.eq('_id', parsed));
      }
    }
    if (order == null) {
      if (orderNumberOrMd5.length == 32 &&
          RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(orderNumberOrMd5)) {
        final checkResult = await BakongService.checkTransactionByMd5(orderNumberOrMd5);
        return {
          'isPaid': checkResult['isPaid'] == true,
          'bakong': checkResult,
        };
      }
      throw const HttpException('Order not found');
    }

    if (order['paymentMethod']?['status'] == 'paid') {
      return {
        'order': cleanDoc(order),
        'isPaid': true,
        'message': 'Order is already paid',
      };
    }

    final md5Hash = order['paymentMethod']?['khqr']?['md5']?.toString();
    if (md5Hash == null || md5Hash.isEmpty) {
      throw const HttpException('Order does not have a Bakong KHQR MD5 hash');
    }

    final checkResult = await BakongService.checkTransactionByMd5(md5Hash);
    final isPaid = checkResult['isPaid'] == true;

    if (isPaid) {
      final now = DateTime.now().toUtc();
      await Database.orders.updateOne(
        where.eq('_id', order['_id']),
        modify
            .set('paymentMethod.status', 'paid')
            .set('paymentMethod.bakongTransaction', checkResult['data'])
            .set('status', 'processing')
            .set('tracking.1.completed', true)
            .set('updatedAt', now),
      );

      // Notify customer
      await Database.notifications.insertOne({
        '_id': ObjectId(),
        'userId': order['userId'],
        'title': 'Payment Received! 🎉',
        'body': 'Your payment for order #${order['orderNumber']} was successfully verified via Bakong KHQR.',
        'type': 'payment',
        'orderId': (order['_id'] as ObjectId).oid,
        'isRead': false,
        'createdAt': now,
      });

      final updated = await Database.orders.findOne(where.eq('_id', order['_id']));
      return {
        'order': cleanDoc(updated),
        'isPaid': true,
        'bakong': checkResult,
      };
    }

    return {
      'order': cleanDoc(order),
      'isPaid': false,
      'bakong': checkResult,
    };
  }
}

class OrderController {
  static Future<Response> checkout(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final body = await readJsonBody(context);
      final addressId = body['addressId']?.toString();
      final newAddress = body['newAddress'] as Map<String, dynamic>?;
      final paymentMethodId = body['paymentMethodId']?.toString();
      final paymentType = body['paymentType']?.toString() ?? 'card';
      final voucherCode = body['voucherCode']?.toString();
      final useLoyaltyPoints = body['useLoyaltyPoints'] == true;

      final order = await OrderService.checkout(
        userId: userId,
        addressId: addressId,
        newAddress: newAddress,
        paymentMethodId: paymentMethodId,
        paymentType: paymentType,
        voucherCode: voucherCode,
        useLoyaltyPoints: useLoyaltyPoints,
      );
      return jsonSuccess(order, statusCode: HttpStatus.created, message: 'Order created successfully');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> list(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    final status = context.request.uri.queryParameters['status'];

    final list = await OrderService.listOrders(userId, status: status);
    return jsonSuccess(list);
  }

  static Future<Response> detail(RequestContext context, String id) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    final order = await OrderService.getOrder(userId, id);
    if (order == null) {
      return jsonError('Order not found', statusCode: HttpStatus.notFound);
    }
    return jsonSuccess(order);
  }

  static Future<Response> tracking(RequestContext context, String id) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    final order = await OrderService.getOrder(userId, id);
    if (order == null) {
      return jsonError('Order not found', statusCode: HttpStatus.notFound);
    }
    return jsonSuccess({
      'orderNumber': order['orderNumber'],
      'status': order['status'],
      'tracking': order['tracking'] ?? <dynamic>[],
    });
  }

  static Future<Response> cancel(RequestContext context, String id) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final updated = await OrderService.cancelOrder(userId, id);
      return jsonSuccess(updated, message: 'Order cancelled successfully');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> returnRequest(RequestContext context, String id) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final body = await readJsonBody(context);
      final reason = body['reason']?.toString() ?? 'Item not as described';
      final notes = body['notes']?.toString();
      final items = body['items'] as List?;

      final updated = await OrderService.returnOrder(
        userId: userId,
        orderId: id,
        reason: reason,
        items: items,
        notes: notes,
      );
      return jsonSuccess(updated, message: 'Return requested successfully');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> verifyBakongPayment(RequestContext context) async {
    try {
      final body = await readJsonBody(context);
      final ref = body['orderNumber']?.toString() ??
          body['md5']?.toString() ??
          body['orderId']?.toString() ??
          context.request.uri.queryParameters['orderNumber'] ??
          context.request.uri.queryParameters['md5'];

      if (ref == null || ref.isEmpty) {
        return jsonError('orderNumber or md5 is required', statusCode: HttpStatus.badRequest);
      }

      final result = await OrderService.verifyBakongPayment(ref);
      return jsonSuccess(result, message: 'Bakong payment status retrieved');
    } catch (e) {
      return jsonError(e.toString());
    }
  }
}
