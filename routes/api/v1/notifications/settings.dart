import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/notification_controller.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get ||
      context.request.method == HttpMethod.patch) {
    return NotificationController.settings(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
