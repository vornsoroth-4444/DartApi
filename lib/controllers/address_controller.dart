import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';

class AddressService {
  static Future<List<Map<String, dynamic>>> listAddresses(String userId) async {
    await Database.ensureConnected();
    final docs = await Database.addresses
        .find(where.eq('userId', userId).sortBy('isDefault', descending: true))
        .toList();
    return cleanDocs(docs);
  }

  static Future<Map<String, dynamic>> addAddress(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final now = DateTime.now().toUtc();
    final isDefault = data['isDefault'] == true;

    if (isDefault) {
      await Database.addresses.updateMany(
        where.eq('userId', userId),
        modify.set('isDefault', false),
      );
    }

    final doc = {
      '_id': ObjectId(),
      'userId': userId,
      'name': data['name'] ?? '',
      'phone': data['phone'] ?? '',
      'street': data['street'] ?? '',
      'city': data['city'] ?? '',
      'state': data['state'] ?? '',
      'postalCode': data['postalCode'] ?? '',
      'country': data['country'] ?? 'United States',
      'label': data['label'] ?? 'Home',
      'isDefault': isDefault,
      'createdAt': now,
      'updatedAt': now,
    };

    await Database.addresses.insertOne(doc);
    return cleanDoc(doc)!;
  }

  static Future<Map<String, dynamic>> updateAddress(
    String userId,
    String id,
    Map<String, dynamic> data,
  ) async {
    final modifier = modify.set('updatedAt', DateTime.now().toUtc());
    if (data.containsKey('name')) modifier.set('name', data['name']);
    if (data.containsKey('phone')) modifier.set('phone', data['phone']);
    if (data.containsKey('street')) modifier.set('street', data['street']);
    if (data.containsKey('city')) modifier.set('city', data['city']);
    if (data.containsKey('state')) modifier.set('state', data['state']);
    if (data.containsKey('postalCode')) modifier.set('postalCode', data['postalCode']);
    if (data.containsKey('country')) modifier.set('country', data['country']);
    if (data.containsKey('label')) modifier.set('label', data['label']);

    if (data['isDefault'] == true) {
      await Database.addresses.updateMany(
        where.eq('userId', userId),
        modify.set('isDefault', false),
      );
      modifier.set('isDefault', true);
    }

    await Database.addresses.updateOne(
      where.eq('userId', userId).eq('_id', parseId(id)),
      modifier,
    );

    final updated = await Database.addresses.findOne(
      where.eq('userId', userId).eq('_id', parseId(id)),
    );
    if (updated == null) throw const HttpException('Address not found');
    return cleanDoc(updated)!;
  }

  static Future<void> deleteAddress(String userId, String id) async {
    await Database.addresses.remove(
      where.eq('userId', userId).eq('_id', parseId(id)),
    );
  }

  static Future<Map<String, dynamic>> setDefault(String userId, String id) async {
    await Database.addresses.updateMany(
      where.eq('userId', userId),
      modify.set('isDefault', false),
    );
    await Database.addresses.updateOne(
      where.eq('userId', userId).eq('_id', parseId(id)),
      modify.set('isDefault', true).set('updatedAt', DateTime.now().toUtc()),
    );

    final updated = await Database.addresses.findOne(
      where.eq('userId', userId).eq('_id', parseId(id)),
    );
    if (updated == null) throw const HttpException('Address not found');
    return cleanDoc(updated)!;
  }
}

class AddressController {
  static Future<Response> list(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    final list = await AddressService.listAddresses(userId);
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
      final address = await AddressService.addAddress(userId, body);
      return jsonSuccess(address, statusCode: HttpStatus.created, message: 'Address created');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> update(RequestContext context, String id) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final body = await readJsonBody(context);
      final address = await AddressService.updateAddress(userId, id, body);
      return jsonSuccess(address, message: 'Address updated');
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

    await AddressService.deleteAddress(userId, id);
    return jsonSuccess({'message': 'Address deleted'});
  }

  static Future<Response> setDefault(RequestContext context, String id) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final address = await AddressService.setDefault(userId, id);
      return jsonSuccess(address, message: 'Default address set');
    } catch (e) {
      return jsonError(e.toString());
    }
  }
}
