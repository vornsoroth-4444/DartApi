import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtUtils {
  static String get secret =>
      Platform.environment['JWT_SECRET'] ?? 'my_api_jwt_secret_key_dev';

  static String signToken(String userId, String email) {
    final jwt = JWT(
      {
        'userId': userId,
        'email': email,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      issuer: 'my_api',
    );

    return jwt.sign(
      SecretKey(secret),
      expiresIn: const Duration(days: 30),
    );
  }

  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(secret), issuer: 'my_api');
      if (jwt.payload is Map<String, dynamic>) {
        return jwt.payload as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? getUserFromContext(RequestContext context) {
    final authHeader = context.request.headers['authorization'] ??
        context.request.headers['Authorization'];

    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }

    final token = authHeader.substring(7).trim();
    return verifyToken(token);
  }
}
