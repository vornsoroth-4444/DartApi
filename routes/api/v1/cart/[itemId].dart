import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/cart_controller.dart';

Future<Response> onRequest(RequestContext context, String itemId) async {
  if (context.request.method == HttpMethod.patch) {
    return CartController.update(context, itemId);
  }
  if (context.request.method == HttpMethod.delete) {
    return CartController.remove(context, itemId);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
