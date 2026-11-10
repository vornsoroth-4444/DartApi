import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';

class StyleFeedService {
  static Future<List<Map<String, dynamic>>> listPosts(String? userId) async {
    await Database.ensureConnected();
    final docs = await Database.styleFeed.find(where.sortBy('createdAt', descending: true)).toList();
    final result = <Map<String, dynamic>>[];

    for (final doc in docs) {
      final cleaned = cleanDoc(doc)!;
      final likedBy = (doc['likedByUserIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
      cleaned['isLiked'] = userId != null && likedBy.contains(userId);

      final taggedIds = (doc['taggedProductIds'] as List?) ?? [];
      if (taggedIds.isNotEmpty) {
        final products = await Database.products.find({
          r'$or': taggedIds.map((id) => {'_id': parseId(id)}).toList(),
        }).toList();
        cleaned['taggedProducts'] = cleanDocs(products);
      } else {
        cleaned['taggedProducts'] = <Map<String, dynamic>>[];
      }

      result.add(cleaned);
    }
    return result;
  }

  static Future<Map<String, dynamic>> toggleLike(String userId, String postId) async {
    final post = await Database.styleFeed.findOne(where.eq('_id', parseId(postId)));
    if (post == null) throw const HttpException('Style post not found');

    final likedBy = List<String>.from((post['likedByUserIds'] as List?) ?? []);
    final wasLiked = likedBy.contains(userId);
    int likesCount = parseInt(post['likesCount'], 0);

    if (wasLiked) {
      likedBy.remove(userId);
      likesCount = (likesCount - 1).clamp(0, 999999);
    } else {
      likedBy.add(userId);
      likesCount += 1;
    }

    await Database.styleFeed.updateOne(
      where.eq('_id', parseId(postId)),
      modify.set('likedByUserIds', likedBy).set('likesCount', likesCount),
    );

    return {
      'postId': postId,
      'isLiked': !wasLiked,
      'likesCount': likesCount,
    };
  }
}

class StyleFeedController {
  static Future<Response> list(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    final userId = user?['userId']?.toString();
    final posts = await StyleFeedService.listPosts(userId);
    return jsonSuccess(posts);
  }

  static Future<Response> like(RequestContext context, String id) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final result = await StyleFeedService.toggleLike(userId, id);
      return jsonSuccess(result);
    } catch (e) {
      return jsonError(e.toString());
    }
  }
}
