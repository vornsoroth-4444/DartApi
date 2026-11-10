import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/hash_utils.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    await Database.ensureConnected();
    final cleanEmail = email.trim().toLowerCase();
    final user = await Database.users.findOne(where.eq('email', cleanEmail));
    if (user == null) {
      throw const HttpException('Invalid email or password');
    }

    final salt = user['salt']?.toString() ?? '';
    final hash = HashUtils.hashPassword(password, salt);
    if (hash != user['passwordHash']) {
      throw const HttpException('Invalid email or password');
    }

    final userId = (user['_id'] as ObjectId).oid;
    final token = JwtUtils.signToken(userId, cleanEmail);

    final sanitizedUser = cleanDoc(user)!..remove('passwordHash')..remove('salt');
    return {'token': token, 'user': sanitizedUser};
  }

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    await Database.ensureConnected();
    final cleanEmail = email.trim().toLowerCase();
    final existing = await Database.users.findOne(where.eq('email', cleanEmail));
    if (existing != null) {
      throw const HttpException('Email already registered');
    }

    final salt = HashUtils.generateSalt();
    final hash = HashUtils.hashPassword(password, salt);
    final now = DateTime.now().toUtc();
    final userId = ObjectId();

    final userDoc = {
      '_id': userId,
      'email': cleanEmail,
      'name': name.trim(),
      'passwordHash': hash,
      'salt': salt,
      'phone': phone?.trim() ?? '',
      'avatar':
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
      'provider': 'local',
      'referralCode': 'USER${HashUtils.generateNumericOtp(4)}',
      'loyaltyPoints': 100, // 100 welcome bonus points
      'loyaltyTier': 'Bronze',
      'createdAt': now,
      'updatedAt': now,
    };

    await Database.users.insertOne(userDoc);

    // Initial notification settings
    await Database.notificationSettings.insertOne({
      '_id': ObjectId(),
      'userId': userId.oid,
      'orderUpdates': true,
      'promotions': true,
      'priceAlerts': true,
      'inAppNotifications': true,
      'emailNotifications': true,
      'smsNotifications': false,
      'updatedAt': now,
    });

    final token = JwtUtils.signToken(userId.oid, cleanEmail);
    final sanitizedUser = cleanDoc(userDoc)!..remove('passwordHash')..remove('salt');
    return {'token': token, 'user': sanitizedUser};
  }

  static Future<void> logout(String token) async {
    await Database.tokensBlacklist.insertOne({
      '_id': ObjectId(),
      'token': token,
      'blacklistedAt': DateTime.now().toUtc(),
    });
  }

  static Future<String> forgotPassword(String email) async {
    await Database.ensureConnected();
    final cleanEmail = email.trim().toLowerCase();
    final user = await Database.users.findOne(where.eq('email', cleanEmail));
    if (user == null) {
      throw const HttpException('No account found with this email');
    }

    final otp = HashUtils.generateNumericOtp(6);
    await Database.otps.remove(where.eq('email', cleanEmail));
    await Database.otps.insertOne({
      '_id': ObjectId(),
      'email': cleanEmail,
      'otp': otp,
      'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 15)),
    });

    return otp;
  }

  static Future<void> verifyOtpAndReset({
    required String email,
    required String otp,
    String? newPassword,
  }) async {
    await Database.ensureConnected();
    final cleanEmail = email.trim().toLowerCase();
    final record = await Database.otps.findOne(where.eq('email', cleanEmail));
    if (record == null || record['otp'] != otp.trim()) {
      throw const HttpException('Invalid or expired OTP');
    }

    final expiresAt = record['expiresAt'] as DateTime?;
    if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
      throw const HttpException('OTP has expired');
    }

    if (newPassword != null && newPassword.trim().isNotEmpty) {
      final salt = HashUtils.generateSalt();
      final hash = HashUtils.hashPassword(newPassword.trim(), salt);
      await Database.users.updateOne(
        where.eq('email', cleanEmail),
        modify.set('passwordHash', hash).set('salt', salt).set('updatedAt', DateTime.now().toUtc()),
      );
    }

    await Database.otps.remove(where.eq('email', cleanEmail));
  }

  static Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String email,
    String? name,
    String? avatar,
  }) async {
    await Database.ensureConnected();
    final cleanEmail = email.trim().toLowerCase();
    var user = await Database.users.findOne(where.eq('email', cleanEmail));

    final now = DateTime.now().toUtc();
    if (user == null) {
      final userId = ObjectId();
      final userDoc = {
        '_id': userId,
        'email': cleanEmail,
        'name': name?.trim() ?? 'User',
        'avatar': avatar ??
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
        'provider': provider.toLowerCase(),
        'referralCode': 'USER${HashUtils.generateNumericOtp(4)}',
        'loyaltyPoints': 100,
        'loyaltyTier': 'Bronze',
        'createdAt': now,
        'updatedAt': now,
      };
      await Database.users.insertOne(userDoc);
      user = userDoc;
    }

    final userId = (user['_id'] as ObjectId).oid;
    final token = JwtUtils.signToken(userId, cleanEmail);
    final sanitized = cleanDoc(user)!..remove('passwordHash')..remove('salt');
    return {'token': token, 'user': sanitized};
  }

  static Future<Map<String, dynamic>> getCurrentUser(String userId) async {
    await Database.ensureConnected();
    final parsed = parseId(userId);
    final user = await Database.users.findOne(where.eq('_id', parsed));
    if (user == null) {
      throw const HttpException('User not found');
    }
    return cleanDoc(user)!..remove('passwordHash')..remove('salt');
  }

  static Future<Map<String, dynamic>> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await Database.ensureConnected();
    final parsed = parseId(userId);
    final modifier = modify.set('updatedAt', DateTime.now().toUtc());

    if (updates.containsKey('name')) modifier.set('name', updates['name']);
    if (updates.containsKey('phone')) modifier.set('phone', updates['phone']);
    if (updates.containsKey('dob')) modifier.set('dob', updates['dob']);
    if (updates.containsKey('avatar')) modifier.set('avatar', updates['avatar']);

    await Database.users.updateOne(where.eq('_id', parsed), modifier);
    return getCurrentUser(userId);
  }
}

class AuthController {
  static Future<Response> login(RequestContext context) async {
    try {
      final body = await readJsonBody(context);
      final email = body['email']?.toString() ?? '';
      final password = body['password']?.toString() ?? '';
      if (email.isEmpty || password.isEmpty) {
        return jsonError('Email and password are required');
      }
      final result = await AuthService.login(email, password);
      return jsonSuccess(result, message: 'Login successful');
    } catch (e) {
      return jsonError(e.toString(), statusCode: HttpStatus.unauthorized);
    }
  }

  static Future<Response> signup(RequestContext context) async {
    try {
      final body = await readJsonBody(context);
      final name = body['name']?.toString() ?? '';
      final email = body['email']?.toString() ?? '';
      final password = body['password']?.toString() ?? '';
      final phone = body['phone']?.toString();

      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        return jsonError('Name, email, and password are required');
      }

      final result = await AuthService.signup(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      return jsonSuccess(result, statusCode: HttpStatus.created, message: 'Account registered successfully');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> logout(RequestContext context) async {
    final authHeader = context.request.headers['authorization'] ??
        context.request.headers['Authorization'];
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      final token = authHeader.substring(7).trim();
      await AuthService.logout(token);
    }
    return jsonSuccess({'message': 'Logged out successfully'});
  }

  static Future<Response> forgotPassword(RequestContext context) async {
    try {
      final body = await readJsonBody(context);
      final email = body['email']?.toString() ?? '';
      if (email.isEmpty) return jsonError('Email is required');

      final otp = await AuthService.forgotPassword(email);
      return jsonSuccess({
        'message': 'OTP sent to email',
        'otpPreview': otp, // returned for development convenience
      });
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> verifyOtp(RequestContext context) async {
    try {
      final body = await readJsonBody(context);
      final email = body['email']?.toString() ?? '';
      final otp = body['otp']?.toString() ?? '';
      final newPassword = body['newPassword']?.toString();

      if (email.isEmpty || otp.isEmpty) {
        return jsonError('Email and OTP are required');
      }

      await AuthService.verifyOtpAndReset(email: email, otp: otp, newPassword: newPassword);
      return jsonSuccess({'message': 'OTP verified successfully'});
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> social(RequestContext context) async {
    try {
      final body = await readJsonBody(context);
      final provider = body['provider']?.toString() ?? 'google';
      final email = body['email']?.toString() ?? '';
      final name = body['name']?.toString();
      final avatar = body['avatar']?.toString();

      if (email.isEmpty) return jsonError('Email is required for social login');

      final result = await AuthService.socialLogin(
        provider: provider,
        email: email,
        name: name,
        avatar: avatar,
      );
      return jsonSuccess(result, message: 'Social login successful');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> me(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Unauthorized', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    if (context.request.method == HttpMethod.get) {
      try {
        final profile = await AuthService.getCurrentUser(userId);
        return jsonSuccess(profile);
      } catch (e) {
        return jsonError(e.toString());
      }
    } else if (context.request.method == HttpMethod.patch) {
      try {
        final body = await readJsonBody(context);
        final updated = await AuthService.updateProfile(userId, body);
        return jsonSuccess(updated, message: 'Profile updated');
      } catch (e) {
        return jsonError(e.toString());
      }
    }
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
}
