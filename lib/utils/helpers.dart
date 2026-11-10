import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mongo_dart/mongo_dart.dart';

dynamic parseId(dynamic id) {
  if (id == null) return null;
  if (id is ObjectId) return id;
  final str = id.toString();
  if (str.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(str)) {
    try {
      return ObjectId.fromHexString(str);
    } catch (_) {}
  }
  return str;
}

Map<String, dynamic> idFilter(String id, {String key = '_id'}) {
  final parsed = parseId(id);
  if (parsed is ObjectId) {
    return {
      r'$or': [
        {key: parsed},
        {key: id},
      ],
    };
  }
  return {key: id};
}

dynamic cleanValue(dynamic val) {
  if (val == null) return null;
  if (val is ObjectId) return val.oid;
  if (val is DateTime) return val.toIso8601String();
  if (val is Int64) return val.toInt();
  if (val.runtimeType.toString() == 'Int64') {
    try {
      return (val as dynamic).toInt();
    } catch (_) {
      return val.toString();
    }
  }
  if (val is Map) {
    return cleanDoc(Map<String, dynamic>.from(val));
  }
  if (val is List) {
    return val.map((dynamic item) => cleanValue(item)).toList();
  }
  return val;
}

Map<String, dynamic>? cleanDoc(Map<String, dynamic>? doc) {
  if (doc == null) return null;
  final result = <String, dynamic>{};
  for (final entry in doc.entries) {
    final key = entry.key;
    final val = entry.value;
    if (key == '_id') {
      final idStr = val is ObjectId ? val.oid : val.toString();
      result['id'] = idStr;
      result['_id'] = idStr;
    } else {
      result[key] = cleanValue(val);
    }
  }
  return result;
}

List<Map<String, dynamic>> cleanDocs(Iterable<dynamic> docs) {
  return docs
      .whereType<Map<String, dynamic>>()
      .map((doc) => cleanDoc(doc)!)
      .toList();
}

double parseDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is Int64) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

int parseInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is Int64) return value.toInt();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

Future<Map<String, dynamic>> readJsonBody(RequestContext context) async {
  try {
    final raw = await context.request.body();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  } catch (e) {
    throw FormatException('Invalid JSON payload: $e');
  }
}

Response jsonSuccess(dynamic data, {int statusCode = HttpStatus.ok, String? message}) {
  final body = <String, dynamic>{
    'success': true,
    if (message != null) 'message': message,
    if (data is Map<String, dynamic>) ...data else 'data': data,
  };
  return Response.json(statusCode: statusCode, body: cleanValue(body));
}

Response jsonError(String message, {int statusCode = HttpStatus.badRequest, dynamic details}) {
  return Response.json(
    statusCode: statusCode,
    body: cleanValue({
      'success': false,
      'error': message,
      if (details != null) 'details': details,
    }),
  );
}
