import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/product_controller.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return ProductController.list(context);
  }
  if (context.request.method == HttpMethod.post) {
    return ProductController.create(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
