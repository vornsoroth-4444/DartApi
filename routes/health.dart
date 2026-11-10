import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/mongo.dart';

Response onRequest(RequestContext context) {
  final db = context.read<Db>();

  return Response.json(
    body: {
      'status': 'online',
      'mongodb': {
        'connected': db.isConnected,
        'state': db.state.toString(),
        'database': db.databaseName,
        'uri': MongoService.connectionUri,
      },
    },
  );
}
