import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/payment_controller.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return PaymentMethodController.list(context);
  }
  if (context.request.method == HttpMethod.post) {
    return PaymentMethodController.add(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
