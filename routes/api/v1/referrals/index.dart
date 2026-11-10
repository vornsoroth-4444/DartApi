import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/controllers/voucher_controller.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return VoucherController.getReferrals(context);
  }
  if (context.request.method == HttpMethod.post) {
    return VoucherController.submitReferral(context);
  }
  return Response(statusCode: HttpStatus.methodNotAllowed);
}
