import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';

class PaymentMethodService {
  static Future<List<Map<String, dynamic>>> list(String userId) async {
    await Database.ensureConnected();
    final docs = await Database.paymentMethods
        .find(where.eq('userId', userId).sortBy('isDefault', descending: true))
        .toList();
    return cleanDocs(docs);
  }

  static Future<Map<String, dynamic>> add(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final now = DateTime.now().toUtc();
    final isDefault = data['isDefault'] == true;

    if (isDefault) {
      await Database.paymentMethods.updateMany(
        where.eq('userId', userId),
        modify.set('isDefault', false),
      );
    }

    // Never store full card number or CVV!
    final doc = {
      '_id': ObjectId(),
      'userId': userId,
      'type': data['type'] ?? 'card',
      'brand': data['brand'] ?? 'Visa',
      'last4': data['last4'] ?? '4242',
      'cardHolder': (data['cardHolder'] ?? 'Card Holder').toString().toUpperCase(),
      'expiryMonth': parseInt(data['expiryMonth'], 12),
      'expiryYear': parseInt(data['expiryYear'], 2028),
      'token': data['token'] ?? 'tok_${ObjectId().oid}',
      'isDefault': isDefault,
      'createdAt': now,
      'updatedAt': now,
    };

    await Database.paymentMethods.insertOne(doc);
    return cleanDoc(doc)!;
  }

  static Future<void> delete(String userId, String id) async {
    await Database.paymentMethods.remove(
      where.eq('userId', userId).eq('_id', parseId(id)),
    );
  }

  static Future<Map<String, dynamic>> setDefault(String userId, String id) async {
    await Database.paymentMethods.updateMany(
      where.eq('userId', userId),
      modify.set('isDefault', false),
    );
    await Database.paymentMethods.updateOne(
      where.eq('userId', userId).eq('_id', parseId(id)),
      modify.set('isDefault', true).set('updatedAt', DateTime.now().toUtc()),
    );

    final updated = await Database.paymentMethods.findOne(
      where.eq('userId', userId).eq('_id', parseId(id)),
    );
    if (updated == null) throw const HttpException('Payment method not found');
    return cleanDoc(updated)!;
  }
}

class PaymentMethodController {
  static Future<Response> list(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    final list = await PaymentMethodService.list(userId);
    return jsonSuccess(list);
  }

  static Future<Response> add(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final body = await readJsonBody(context);
      final item = await PaymentMethodService.add(userId, body);
      return jsonSuccess(item, statusCode: HttpStatus.created, message: 'Payment method added');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> delete(RequestContext context, String id) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    await PaymentMethodService.delete(userId, id);
    return jsonSuccess({'message': 'Payment method deleted'});
  }

  static Future<Response> setDefault(RequestContext context, String id) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final item = await PaymentMethodService.setDefault(userId, id);
      return jsonSuccess(item, message: 'Default payment method set');
    } catch (e) {
      return jsonError(e.toString());
    }
  }
}
