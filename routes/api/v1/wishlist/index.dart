import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/wishlist_controller.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return WishlistController.get(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
