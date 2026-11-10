import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/mongo.dart';

Future<Response> onRequest(RequestContext context) async {
  final db = context.read<Db>();
  final collection = db.collection('items');

  if (context.request.method == HttpMethod.get) {
    final rawDocs = await collection.find().toList();
    final items = rawDocs.map((doc) => doc.toJsonEncodable()).toList();
    return Response.json(body: items);
  }

  if (context.request.method == HttpMethod.post) {
    try {
      final body = await context.request.json() as Map<String, dynamic>;
      final result = await collection.insertOne(body);

      return Response.json(
        statusCode: HttpStatus.created,
        body: {
          'success': result.isSuccess,
          'id': (body['_id'] as ObjectId?)?.oid,
          'data': body.toJsonEncodable(),
        },
      );
    } catch (e) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'error': 'Invalid JSON body', 'details': e.toString()},
      );
    }
  }

  return Response(statusCode: HttpStatus.methodNotAllowed);
}
