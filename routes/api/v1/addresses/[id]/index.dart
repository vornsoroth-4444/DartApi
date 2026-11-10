import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/address_controller.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.patch) {
    return AddressController.update(context, id);
  }
  if (context.request.method == HttpMethod.delete) {
    return AddressController.delete(context, id);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
