import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/order_controller.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) {
    return OrderController.checkout(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
