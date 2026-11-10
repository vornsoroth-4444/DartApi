import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';
import 'seed_data.dart';

class Database {
  static Db? _db;

  static Db get instance {
    if (_db == null || !_db!.isConnected) {
      throw StateError(
        'Database has not been initialized. Call Database.connect() first.',
      );
    }
    return _db!;
  }

  static bool get isConnected => _db != null && _db!.isConnected;

  static String get defaultHost =>
      Platform.environment['MONGODB_HOST'] ?? '127.0.0.1';

  static int get defaultPort {
    final envPort = Platform.environment['MONGODB_PORT'];
    if (envPort != null) return int.tryParse(envPort) ?? 27017;
    return 27017;
  }

  static String get defaultDbName =>
      Platform.environment['MONGODB_DATABASE'] ?? 'my_api_db';

  static String get connectionUri =>
      Platform.environment['MONGODB_URI'] ??
      'mongodb://$defaultHost:$defaultPort/$defaultDbName';

  static Future<Db> connect([String? uri]) async {
    if (_db != null && _db!.isConnected) return _db!;
    final u = uri ?? connectionUri;
    _db = await Db.create(u);
    await _db!.open();
    await _createIndexes();
    await DatabaseSeeder.seedIfEmpty();
    return _db!;
  }

  static Future<Db> ensureConnected() async {
    if (_db == null || !_db!.isConnected) {
      return connect();
    }
    return _db!;
  }

  static Future<void> _createIndexes() async {
    try {
      await users.createIndex(keys: {'email': 1}, unique: true);
      await products.createIndex(keys: {'slug': 1});
      await products.createIndex(keys: {'category': 1});
      await categories.createIndex(keys: {'slug': 1});
      await vouchers.createIndex(keys: {'code': 1}, unique: true);
      await tokensBlacklist.createIndex(keys: {'token': 1});
    } catch (_) {}
  }

  static Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
    }
    _db = null;
  }

  // Collections
  static DbCollection get users => instance.collection('users');
  static DbCollection get tokensBlacklist =>
      instance.collection('tokens_blacklist');
  static DbCollection get otps => instance.collection('otps');
  static DbCollection get categories => instance.collection('categories');
  static DbCollection get brands => instance.collection('brands');
  static DbCollection get products => instance.collection('products');
  static DbCollection get reviews => instance.collection('reviews');
  static DbCollection get wishlists => instance.collection('wishlists');
  static DbCollection get carts => instance.collection('carts');
  static DbCollection get addresses => instance.collection('addresses');
  static DbCollection get paymentMethods =>
      instance.collection('payment_methods');
  static DbCollection get orders => instance.collection('orders');
  static DbCollection get vouchers => instance.collection('vouchers');
  static DbCollection get loyaltyHistory =>
      instance.collection('loyalty_history');
  static DbCollection get referrals => instance.collection('referrals');
  static DbCollection get notificationSettings =>
      instance.collection('notification_settings');
  static DbCollection get notifications =>
      instance.collection('notifications');
  static DbCollection get faqs => instance.collection('faqs');
  static DbCollection get supportChats => instance.collection('support_chats');
  static DbCollection get styleFeed => instance.collection('style_feed');
}
