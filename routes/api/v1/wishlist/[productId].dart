import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/wishlist_controller.dart';

Future<Response> onRequest(RequestContext context, String productId) async {
  if (context.request.method == HttpMethod.post) {
    return WishlistController.add(context, productId);
  }
  if (context.request.method == HttpMethod.delete) {
    return WishlistController.remove(context, productId);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
