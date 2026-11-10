import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';

class WishlistService {
  static Future<List<Map<String, dynamic>>> getWishlist(String userId) async {
    await Database.ensureConnected();
    final items = await Database.wishlists.find(where.eq('userId', userId)).toList();
    final result = <Map<String, dynamic>>[];

    for (final item in items) {
      final productId = item['productId']?.toString();
      Map<String, dynamic>? product;
      if (productId != null) {
        product = await Database.products.findOne(where.eq('_id', parseId(productId)));
      }
      final cleaned = cleanDoc(item)!;
      if (product != null) {
        cleaned['product'] = cleanDoc(product);
      }
      result.add(cleaned);
    }
    return result;
  }

  static Future<Map<String, dynamic>> addToWishlist(String userId, String productId) async {
    final existing = await Database.wishlists.findOne(
      where.eq('userId', userId).eq('productId', productId),
    );

    if (existing != null) {
      return cleanDoc(existing)!;
    }

    final doc = {
      '_id': ObjectId(),
      'userId': userId,
      'productId': productId,
      'addedAt': DateTime.now().toUtc(),
    };
    await Database.wishlists.insertOne(doc);
    return cleanDoc(doc)!;
  }

  static Future<void> removeFromWishlist(String userId, String productId) async {
    await Database.wishlists.remove(
      where.eq('userId', userId).eq('productId', productId),
    );
  }
}

class WishlistController {
  static Future<Response> get(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    final list = await WishlistService.getWishlist(userId);
    return jsonSuccess(list);
  }

  static Future<Response> add(RequestContext context, String productId) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    final item = await WishlistService.addToWishlist(userId, productId);
    return jsonSuccess(item, message: 'Added to wishlist');
  }

  static Future<Response> remove(RequestContext context, String productId) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    await WishlistService.removeFromWishlist(userId, productId);
    return jsonSuccess({'message': 'Removed from wishlist'});
  }
}
