import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';

class CartService {
  static Future<Map<String, dynamic>> getCart(String userId) async {
    await Database.ensureConnected();
    var cart = await Database.carts.findOne(where.eq('userId', userId));
    if (cart == null) {
      cart = {
        '_id': ObjectId(),
        'userId': userId,
        'items': <Map<String, dynamic>>[],
        'createdAt': DateTime.now().toUtc(),
        'updatedAt': DateTime.now().toUtc(),
      };
      await Database.carts.insertOne(cart);
    }

    final rawItems = (cart['items'] as List?) ?? [];
    double subtotal = 0;
    final items = <Map<String, dynamic>>[];

    for (final raw in rawItems) {
      if (raw is Map) {
        final itemMap = Map<String, dynamic>.from(raw);
        final price = parseDouble(itemMap['price']);
        final qty = parseInt(itemMap['quantity'], 1);
        subtotal += price * qty;
        items.add(cleanDoc(itemMap)!);
      }
    }

    const shipping = 0.0;
    final total = subtotal + shipping;

    final cleaned = cleanDoc(cart)!;
    cleaned['items'] = items;
    cleaned['subtotal'] = double.parse(subtotal.toStringAsFixed(2));
    cleaned['shipping'] = shipping;
    cleaned['total'] = double.parse(total.toStringAsFixed(2));
    cleaned['itemCount'] = items.fold<int>(0, (sum, i) => sum + (parseInt(i['quantity'], 1)));

    return cleaned;
  }

  static Future<Map<String, dynamic>> addItem({
    required String userId,
    required String productId,
    required int quantity,
    String? color,
    String? size,
  }) async {
    final product = await Database.products.findOne(where.eq('_id', parseId(productId)));
    if (product == null) {
      throw const HttpException('Product not found');
    }

    final stock = parseInt(product['stock'], 0);
    if (stock < quantity) {
      throw HttpException('Insufficient stock available. Only $stock left.');
    }

    final flashSale = product['flashSale'] as Map?;
    final price = (flashSale != null && flashSale['active'] == true && flashSale['salePrice'] != null)
        ? parseDouble(flashSale['salePrice'])
        : parseDouble(product['price']);

    var cart = await Database.carts.findOne(where.eq('userId', userId));
    if (cart == null) {
      cart = {
        '_id': ObjectId(),
        'userId': userId,
        'items': <Map<String, dynamic>>[],
        'createdAt': DateTime.now().toUtc(),
        'updatedAt': DateTime.now().toUtc(),
      };
      await Database.carts.insertOne(cart);
    }

    final items = _extractItems(cart['items']);
    final existingIndex = items.indexWhere(
      (it) => it['productId'] == productId && it['color'] == color && it['size'] == size,
    );

    if (existingIndex >= 0) {
      final currentQty = parseInt(items[existingIndex]['quantity'], 1);
      items[existingIndex]['quantity'] = currentQty + quantity;
    } else {
      items.add({
        'itemId': ObjectId().oid,
        'productId': productId,
        'name': product['name'],
        'price': price,
        'quantity': quantity,
        'color': color ?? (product['colors'] is List && (product['colors'] as List).isNotEmpty ? product['colors'][0] : null),
        'size': size ?? (product['sizes'] is List && (product['sizes'] as List).isNotEmpty ? product['sizes'][0] : null),
        'image': product['thumbnail'] ?? (product['images'] is List && (product['images'] as List).isNotEmpty ? product['images'][0] : null),
      });
    }

    await Database.carts.updateOne(
      where.eq('userId', userId),
      modify.set('items', items).set('updatedAt', DateTime.now().toUtc()),
    );

    return getCart(userId);
  }

  static Future<Map<String, dynamic>> updateItem({
    required String userId,
    required String itemId,
    int? quantity,
    String? color,
    String? size,
  }) async {
    final cart = await Database.carts.findOne(where.eq('userId', userId));
    if (cart == null) throw const HttpException('Cart not found');

    final items = _extractItems(cart['items']);
    final index = items.indexWhere((it) => it['itemId'] == itemId);
    if (index < 0) throw const HttpException('Item not found in cart');

    if (quantity != null) {
      if (quantity <= 0) {
        items.removeAt(index);
      } else {
        items[index]['quantity'] = quantity;
      }
    }
    if (color != null) items[index]['color'] = color;
    if (size != null) items[index]['size'] = size;

    await Database.carts.updateOne(
      where.eq('userId', userId),
      modify.set('items', items).set('updatedAt', DateTime.now().toUtc()),
    );

    return getCart(userId);
  }

  static Future<Map<String, dynamic>> removeItem(String userId, String itemId) async {
    final cart = await Database.carts.findOne(where.eq('userId', userId));
    if (cart == null) throw const HttpException('Cart not found');

    final items = _extractItems(cart['items']);
    items.removeWhere((it) => it['itemId'] == itemId);

    await Database.carts.updateOne(
      where.eq('userId', userId),
      modify.set('items', items).set('updatedAt', DateTime.now().toUtc()),
    );

    return getCart(userId);
  }

  static Future<void> clearCart(String userId) async {
    await Database.carts.updateOne(
      where.eq('userId', userId),
      modify.set('items', <Map<String, dynamic>>[]).set('updatedAt', DateTime.now().toUtc()),
    );
  }
}

class CartController {
  static Future<Response> get(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    final cart = await CartService.getCart(userId);
    return jsonSuccess(cart);
  }

  static Future<Response> add(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final body = await readJsonBody(context);
      final productId = body['productId']?.toString();
      final quantity = parseInt(body['quantity'], 1);
      final color = body['color']?.toString();
      final size = body['size']?.toString();

      if (productId == null || productId.isEmpty) {
        return jsonError('productId is required');
      }

      final cart = await CartService.addItem(
        userId: userId,
        productId: productId,
        quantity: quantity,
        color: color,
        size: size,
      );
      return jsonSuccess(cart, message: 'Item added to cart');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> update(RequestContext context, String itemId) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final body = await readJsonBody(context);
      final quantity = body.containsKey('quantity') ? parseInt(body['quantity']) : null;
      final color = body['color']?.toString();
      final size = body['size']?.toString();

      final cart = await CartService.updateItem(
        userId: userId,
        itemId: itemId,
        quantity: quantity,
        color: color,
        size: size,
      );
      return jsonSuccess(cart, message: 'Cart updated');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> remove(RequestContext context, String itemId) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    final cart = await CartService.removeItem(userId, itemId);
    return jsonSuccess(cart, message: 'Item removed from cart');
  }

  static Future<Response> clear(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    await CartService.clearCart(userId);
    final emptyCart = await CartService.getCart(userId);
    return jsonSuccess(emptyCart, message: 'Cart cleared');
  }
}

List<Map<String, dynamic>> _extractItems(dynamic raw) {
  if (raw is! List) return <Map<String, dynamic>>[];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
