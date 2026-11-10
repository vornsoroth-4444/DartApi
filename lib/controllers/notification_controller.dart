import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';

class NotificationService {
  static Future<Map<String, dynamic>> getSettings(String userId) async {
    await Database.ensureConnected();
    var settings = await Database.notificationSettings.findOne(where.eq('userId', userId));
    if (settings == null) {
      settings = {
        '_id': ObjectId(),
        'userId': userId,
        'orderUpdates': true,
        'promotions': true,
        'priceAlerts': true,
        'inAppNotifications': true,
        'emailNotifications': true,
        'smsNotifications': false,
        'updatedAt': DateTime.now().toUtc(),
      };
      await Database.notificationSettings.insertOne(settings);
    }
    return cleanDoc(settings)!;
  }

  static Future<Map<String, dynamic>> updateSettings(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final modifier = modify.set('updatedAt', DateTime.now().toUtc());
    if (data.containsKey('orderUpdates')) modifier.set('orderUpdates', data['orderUpdates'] == true);
    if (data.containsKey('promotions')) modifier.set('promotions', data['promotions'] == true);
    if (data.containsKey('priceAlerts')) modifier.set('priceAlerts', data['priceAlerts'] == true);
    if (data.containsKey('inAppNotifications')) {
      modifier.set('inAppNotifications', data['inAppNotifications'] == true);
    }
    if (data.containsKey('emailNotifications')) {
      modifier.set('emailNotifications', data['emailNotifications'] == true);
    }
    if (data.containsKey('smsNotifications')) {
      modifier.set('smsNotifications', data['smsNotifications'] == true);
    }

    await Database.notificationSettings.updateOne(where.eq('userId', userId), modifier);
    return getSettings(userId);
  }

  static Future<List<Map<String, dynamic>>> listNotifications(String userId) async {
    final docs = await Database.notifications
        .find(where.eq('userId', userId).sortBy('createdAt', descending: true))
        .toList();
    return cleanDocs(docs);
  }
}

class NotificationController {
  static Future<Response> settings(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    if (context.request.method == HttpMethod.get) {
      final s = await NotificationService.getSettings(userId);
      return jsonSuccess(s);
    } else if (context.request.method == HttpMethod.patch) {
      try {
        final body = await readJsonBody(context);
        final updated = await NotificationService.updateSettings(userId, body);
        return jsonSuccess(updated, message: 'Notification settings updated');
      } catch (e) {
        return jsonError(e.toString());
      }
    }
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  static Future<Response> list(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    final list = await NotificationService.listNotifications(userId);
    return jsonSuccess(list);
  }
}
