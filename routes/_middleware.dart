import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/mongo.dart';

Handler middleware(Handler handler) {
  return handler
      .use(requestLogger())
      .use(_databaseProvider());
}

Middleware _databaseProvider() {
  return (Handler handler) {
    return (RequestContext context) async {
      try {
        final db = await Database.connect();
        return await handler(context.provide<Db>(() => db));
      } catch (e) {
        return Response.json(
          statusCode: HttpStatus.serviceUnavailable,
          body: {
            'error': 'Database unavailable',
            'message':
                'Failed to connect to MongoDB on port ${Database.defaultPort}',
            'details': e.toString(),
            'hint':
                'Check if MongoDB is running on port ${Database.defaultPort} or set MONGODB_PORT/MONGODB_URI in environment variables.',
          },
        );
      }

    };
  };
}
