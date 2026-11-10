import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:my_api/utils/jwt_utils.dart';

class VoucherService {
  static Future<List<Map<String, dynamic>>> listVouchers(String? userId) async {
    await Database.ensureConnected();
    final docs = await Database.vouchers.find(where.eq('isActive', true)).toList();
    return cleanDocs(docs);
  }

  static Future<Map<String, dynamic>> applyVoucher(String code, double subtotal) async {
    final v = await Database.vouchers.findOne(
      where.eq('code', code.trim().toUpperCase()).eq('isActive', true),
    );

    if (v == null) {
      throw const HttpException('Invalid voucher code');
    }

    final minSpend = parseDouble(v['minSpend']);
    if (subtotal < minSpend) {
      throw HttpException('Minimum spend of \$$minSpend required to apply this voucher');
    }

    final type = v['discountType']?.toString() ?? 'percentage';
    final val = parseDouble(v['discountValue']);
    double discount = 0.0;

    if (type == 'percentage') {
      discount = subtotal * (val / 100);
      final maxDisc = parseDouble(v['maxDiscount']);
      if (maxDisc > 0 && discount > maxDisc) discount = maxDisc;
    } else {
      discount = val;
    }

    discount = double.parse(discount.toStringAsFixed(2));
    final newTotal = double.parse((subtotal - discount).clamp(0, 999999).toStringAsFixed(2));

    return {
      'valid': true,
      'code': v['code'],
      'discountType': type,
      'discountValue': val,
      'discountAmount': discount,
      'newTotal': newTotal,
      'description': v['description'],
    };
  }

  static Future<Map<String, dynamic>> getLoyalty(String userId) async {
    final user = await Database.users.findOne(where.eq('_id', parseId(userId)));
    final points = parseInt(user?['loyaltyPoints'], 0);
    final tier = user?['loyaltyTier']?.toString() ?? 'Bronze';

    final history = await Database.loyaltyHistory
        .find(where.eq('userId', userId).sortBy('createdAt', descending: true).limit(20))
        .toList();

    return {
      'points': points,
      'tier': tier,
      'dollarValue': (points / 20).toStringAsFixed(2), // 100 points = $5 -> $1 = 20 points
      'history': cleanDocs(history),
    };
  }

  static Future<Map<String, dynamic>> redeemPoints(String userId, int points) async {
    if (points < 100 || points % 100 != 0) {
      throw const HttpException('Points must be redeemed in increments of 100 points (\$5 value)');
    }

    final user = await Database.users.findOne(where.eq('_id', parseId(userId)));
    final currentPoints = parseInt(user?['loyaltyPoints'], 0);
    if (currentPoints < points) {
      throw HttpException('Insufficient points. You only have $currentPoints points.');
    }

    await Database.users.updateOne(
      where.eq('_id', parseId(userId)),
      modify.inc('loyaltyPoints', -points),
    );

    final discountAmount = (points / 100) * 5.0;

    await Database.loyaltyHistory.insertOne({
      '_id': ObjectId(),
      'userId': userId,
      'points': -points,
      'type': 'redeem',
      'description': 'Redeemed for \$$discountAmount discount',
      'createdAt': DateTime.now().toUtc(),
    });

    return {
      'redeemedPoints': points,
      'discountAmount': discountAmount,
      'remainingPoints': currentPoints - points,
    };
  }

  static Future<Map<String, dynamic>> getReferrals(String userId) async {
    final user = await Database.users.findOne(where.eq('_id', parseId(userId)));
    final code = user?['referralCode']?.toString() ?? 'REFERME';

    final referrals = await Database.referrals
        .find(where.eq('referrerId', userId).sortBy('createdAt', descending: true))
        .toList();

    return {
      'referralCode': code,
      'shareUrl': 'https://myapi.shop/join?ref=$code',
      'rewardPerReferral': '150 Points (\$7.50)',
      'totalReferrals': referrals.length,
      'referrals': cleanDocs(referrals),
    };
  }

  static Future<Map<String, dynamic>> submitReferral(String userId, String code) async {
    final cleanCode = code.trim().toUpperCase();
    final referrer = await Database.users.findOne(where.eq('referralCode', cleanCode));

    if (referrer == null) {
      throw const HttpException('Invalid referral code');
    }

    final referrerId = (referrer['_id'] as ObjectId).oid;
    if (referrerId == userId) {
      throw const HttpException('You cannot refer yourself');
    }

    final existing = await Database.referrals.findOne(where.eq('refereeId', userId));
    if (existing != null) {
      throw const HttpException('You have already applied a referral code');
    }

    final now = DateTime.now().toUtc();
    await Database.referrals.insertOne({
      '_id': ObjectId(),
      'referrerId': referrerId,
      'refereeId': userId,
      'code': cleanCode,
      'pointsAwarded': 150,
      'status': 'completed',
      'createdAt': now,
    });

    await Database.users.updateOne(
      where.eq('_id', parseId(referrerId)),
      modify.inc('loyaltyPoints', 150),
    );
    await Database.users.updateOne(
      where.eq('_id', parseId(userId)),
      modify.inc('loyaltyPoints', 100),
    );

    return {'success': true, 'message': 'Referral code applied! You received 100 bonus points.'};
  }
}

class VoucherController {
  static Future<Response> list(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    final userId = user?['userId']?.toString();
    final list = await VoucherService.listVouchers(userId);
    return jsonSuccess(list);
  }

  static Future<Response> apply(RequestContext context) async {
    try {
      final body = await readJsonBody(context);
      final code = body['code']?.toString() ?? '';
      final subtotal = parseDouble(body['subtotal']);

      if (code.isEmpty) return jsonError('Voucher code is required');

      final result = await VoucherService.applyVoucher(code, subtotal);
      return jsonSuccess(result, message: 'Voucher applied successfully');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> points(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    final data = await VoucherService.getLoyalty(userId);
    return jsonSuccess(data);
  }

  static Future<Response> redeem(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final body = await readJsonBody(context);
      final points = parseInt(body['points'], 0);
      final result = await VoucherService.redeemPoints(userId, points);
      return jsonSuccess(result, message: 'Points redeemed successfully');
    } catch (e) {
      return jsonError(e.toString());
    }
  }

  static Future<Response> getReferrals(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';
    final data = await VoucherService.getReferrals(userId);
    return jsonSuccess(data);
  }

  static Future<Response> submitReferral(RequestContext context) async {
    final user = JwtUtils.getUserFromContext(context);
    if (user == null) {
      return jsonError('Authentication required', statusCode: HttpStatus.unauthorized);
    }
    final userId = user['userId']?.toString() ?? '';

    try {
      final body = await readJsonBody(context);
      final code = body['code']?.toString() ?? '';
      if (code.isEmpty) return jsonError('Referral code is required');

      final result = await VoucherService.submitReferral(userId, code);
      return jsonSuccess(result);
    } catch (e) {
      return jsonError(e.toString());
    }
  }
}
