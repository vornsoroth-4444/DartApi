import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';

class SupportService {
  static Future<List<Map<String, dynamic>>> listFaqs() async {
    await Database.ensureConnected();
    final docs = await Database.faqs.find().toList();
    return cleanDocs(docs);
  }

  static Future<List<Map<String, dynamic>>> getChatHistory(String userId) async {
    final docs = await Database.supportChats
        .find(where.eq('userId', userId).sortBy('timestamp', descending: false))
        .toList();
    return cleanDocs(docs);
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String userId,
    required String message,
  }) async {
    final now = DateTime.now().toUtc();
    final userMsg = {
      '_id': ObjectId(),
      'userId': userId,
      'sender': 'user',
      'message': message.trim(),
      'timestamp': now,
    };
    await Database.supportChats.insertOne(userMsg);

    final botResponse = {
      '_id': ObjectId(),
      'userId': userId,
      'sender': 'agent',
      'agentName': 'Sophia (Customer Care)',
      'message':
          'Thank you for reaching out! We received your message: "$message". Our support representative will assist you shortly.',
      'timestamp': now.add(const Duration(seconds: 1)),
    };
    await Database.supportChats.insertOne(botResponse);

    return {
      'userMessage': cleanDoc(userMsg),
      'agentMessage': cleanDoc(botResponse),
    };
  }
}

class SupportController {
  static Future<Response> faqs(RequestContext context) async {
    final list = await SupportService.listFaqs();
    return jsonSuccess(list);
  }

  static Future<Response> history(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    final history = await SupportService.getChatHistory(userId);
    return jsonSuccess(history);
  }

  static Future<Response> send(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final body = await readJsonBody(context);
      final message = body['message']?.toString() ?? '';
      if (message.trim().isEmpty) {
        return jsonError('Message cannot be empty');
      }

      final result = await SupportService.sendMessage(userId: userId, message: message);
      return jsonSuccess(result, statusCode: HttpStatus.created);
    } catch (e) {
      return jsonError(e.toString());
    }
  }
}
