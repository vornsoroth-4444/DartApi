import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/style_feed_controller.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return StyleFeedController.list(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
