import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/review_controller.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.get) {
    return ReviewController.list(context, id);
  }
  if (context.request.method == HttpMethod.post) {
    return ReviewController.submit(context, id);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
