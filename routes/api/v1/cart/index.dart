import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/cart_controller.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return CartController.get(context);
  }
  if (context.request.method == HttpMethod.post) {
    return CartController.add(context);
  }
  if (context.request.method == HttpMethod.delete) {
    return CartController.clear(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
