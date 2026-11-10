import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/payment_controller.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.delete) {
    return PaymentMethodController.delete(context, id);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
