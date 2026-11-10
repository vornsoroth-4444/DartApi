import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

/// Service managing the MongoDB connection lifecycle.
class MongoService {
  MongoService._();

  /// Singleton instance of [MongoService].
  static final MongoService instance = MongoService._();

  Db? _db;

  /// Default MongoDB host.
  static String get host => Platform.environment['MONGODB_HOST'] ?? '127.0.0.1';

  /// MongoDB port. Defaults to 27017 (standard MongoDB port).
  static int get port {
    final envPort = Platform.environment['MONGODB_PORT'];
    if (envPort != null) {
      return int.tryParse(envPort) ?? 27017;
    }
    return 27017;
  }

  /// Default database name.
  static String get databaseName =>
      Platform.environment['MONGODB_DATABASE'] ?? 'my_api_db';

  /// Full MongoDB connection URI.
  static String get connectionUri {
    final envUri = Platform.environment['MONGODB_URI'];
    if (envUri != null && envUri.isNotEmpty) {
      return envUri;
    }
    return 'mongodb://$host:$port/$databaseName';
  }

  /// Returns the connected [Db] instance, creating and opening it if necessary.
  Future<Db> get database async {
    if (_db != null && _db!.isConnected) {
      return _db!;
    }

    _db = await Db.create(connectionUri);
    await _db!.open();
    return _db!;
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
    }
    _db = null;
  }
}

/// Helper extension to convert MongoDB/BSON documents into standard JSON-encodable Maps.
extension MongoDocumentExtension on Map<String, dynamic> {
  /// Converts BSON types (like [ObjectId]) to JSON-serializable types.
  Map<String, dynamic> toJsonEncodable() {
    return _convertBsonToJson(this) as Map<String, dynamic>;
  }
}

dynamic _convertBsonToJson(dynamic value) {
  if (value is ObjectId) {
    return value.oid;
  } else if (value is Map<String, dynamic>) {
    return value.map((k, v) => MapEntry(k, _convertBsonToJson(v)));
  } else if (value is List) {
    return value.map(_convertBsonToJson).toList();
  } else if (value is DateTime) {
    return value.toIso8601String();
  }
  return value;
}
