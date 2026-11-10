import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

class MongoService {
  MongoService._();

  static final MongoService instance = MongoService._();

  Db? _db;

  static String get host => Platform.environment['MONGODB_HOST'] ?? '127.0.0.1';

  static int get port {
    final envPort = Platform.environment['MONGODB_PORT'];
    if (envPort != null) {
      return int.tryParse(envPort) ?? 27017;
    }
    return 27017;
  }

  static String get databaseName =>
      Platform.environment['MONGODB_DATABASE'] ?? 'my_api_db';

  static String get connectionUri {
    final envUri = Platform.environment['MONGODB_URI'];
    if (envUri != null && envUri.isNotEmpty) {
      return envUri;
    }
    return 'mongodb://$host:$port/$databaseName';
  }

  Future<Db> get database async {
    if (_db != null && _db!.isConnected) {
      return _db!;
    }

    _db = await Db.create(connectionUri);
    await _db!.open();
    return _db!;
  }

  Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
    }
    _db = null;
  }
}

extension MongoDocumentExtension on Map<String, dynamic> {
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
