import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/auth_controller.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get ||
      context.request.method == HttpMethod.patch) {
    return AuthController.me(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
