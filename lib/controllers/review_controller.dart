import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';

class ReviewService {
  static Future<Map<String, dynamic>> getProductReviews(
    String productId, {
    int page = 1,
    int limit = 10,
  }) async {
    await Database.ensureConnected();
    final query = {
      r'$or': [
        {'productId': productId},
        {'productId': parseId(productId)},
      ],
    };

    final total = await Database.reviews.count(query);
    final skip = (page - 1) * limit;
    final docs = await Database.reviews
        .find(where.eq(r'$or', query[r'$or']).sortBy('createdAt', descending: true).skip(skip).limit(limit))
        .toList();

    return {
      'reviews': cleanDocs(docs),
      'pagination': {
        'total': total,
        'page': page,
        'limit': limit,
        'totalPages': (total / limit).ceil(),
      },
    };
  }

  static Future<Map<String, dynamic>> submitReview({
    required String productId,
    required String userId,
    required int rating,
    required String text,
    List<String> photos = const [],
  }) async {
    final user = await Database.users.findOne(where.eq('_id', parseId(userId)));
    final now = DateTime.now().toUtc();

    final reviewDoc = {
      '_id': ObjectId(),
      'productId': productId,
      'userId': userId,
      'userName': user?['name'] ?? 'Verified Buyer',
      'userAvatar': user?['avatar'] ??
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=100&q=80',
      'rating': rating,
      'text': text.trim(),
      'photos': photos,
      'createdAt': now,
    };

    await Database.reviews.insertOne(reviewDoc);

    // Recalculate average rating for product
    final allReviews = await Database.reviews.find({
      r'$or': [
        {'productId': productId},
        {'productId': parseId(productId)},
      ],
    }).toList();

    if (allReviews.isNotEmpty) {
      final totalStars = allReviews.fold<num>(0, (sum, r) => sum + (r['rating'] as num? ?? 5));
      final avg = double.parse((totalStars / allReviews.length).toStringAsFixed(1));

      await Database.products.updateOne(
        where.eq('_id', parseId(productId)),
        modify.set('rating', avg).set('reviewCount', allReviews.length),
      );
    }

    return cleanDoc(reviewDoc)!;
  }

  static Future<Map<String, dynamic>> getReviewSummary(String productId) async {
    final reviews = await Database.reviews.find({
      r'$or': [
        {'productId': productId},
        {'productId': parseId(productId)},
      ],
    }).toList();

    final total = reviews.length;
    final counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    num totalStars = 0;

    for (final r in reviews) {
      final star = (r['rating'] as num? ?? 5).clamp(1, 5).toInt();
      counts[star] = (counts[star] ?? 0) + 1;
      totalStars += star;
    }

    final average = total > 0 ? double.parse((totalStars / total).toStringAsFixed(1)) : 5.0;

    return {
      'totalReviews': total,
      'averageRating': average,
      'breakdown': counts.map(
        (key, count) => MapEntry(
          key.toString(),
          {
            'count': count,
            'percentage': total > 0 ? ((count / total) * 100).round() : 0,
          },
        ),
      ),
    };
  }
}

class ReviewController {
  static Future<Response> list(RequestContext context, String productId) async {
    final params = context.request.uri.queryParameters;
    final page = int.tryParse(params['page'] ?? '1') ?? 1;
    final limit = int.tryParse(params['limit'] ?? '10') ?? 10;

    final data = await ReviewService.getProductReviews(productId, page: page, limit: limit);
    return jsonSuccess(data);
  }

  static Future<Response> submit(RequestContext context, String productId) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final body = await readJsonBody(context);
      final rating = parseInt(body['rating'], 5).clamp(1, 5);
      final text = body['text']?.toString() ?? '';
      final photos = (body['photos'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

      final review = await ReviewService.submitReview(
        productId: productId,
        userId: userId,
        rating: rating,
        text: text,
        photos: photos,
      );
      return jsonSuccess(review, statusCode: HttpStatus.created, message: 'Review submitted');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> summary(RequestContext context, String productId) async {
    final data = await ReviewService.getReviewSummary(productId);
    return jsonSuccess(data);
  }
}
