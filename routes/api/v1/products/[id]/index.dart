import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/product_controller.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.get) {
    return ProductController.detail(context, id);
  }
  if (context.request.method == HttpMethod.put ||
      context.request.method == HttpMethod.patch) {
    return ProductController.update(context, id);
  }
  if (context.request.method == HttpMethod.delete) {
    return ProductController.delete(context, id);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
