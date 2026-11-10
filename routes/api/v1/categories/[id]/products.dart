import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/product_controller.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.get) {
    return ProductController.categoryProducts(context, id);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
