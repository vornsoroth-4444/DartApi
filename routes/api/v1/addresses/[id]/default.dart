import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/address_controller.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.patch) {
    return AddressController.setDefault(context, id);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
