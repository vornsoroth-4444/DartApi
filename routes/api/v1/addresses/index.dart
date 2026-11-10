import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/address_controller.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return AddressController.list(context);
  }
  if (context.request.method == HttpMethod.post) {
    return AddressController.add(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
