import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:my_api/services/bakong_service.dart';
import 'package:my_api/utils/helpers.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await readJsonBody(context);
    final amount = parseDouble(body['amount'], 4000.0);
    final currency = body['currency']?.toString().toUpperCase() ?? BakongService.defaultCurrency;
    final billNumber = body['billNumber']?.toString() ??
        'BILL-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final storeLabel = body['storeLabel']?.toString();

    final result = await BakongService.createKhqrPayment(
      amount: amount,
      currency: currency,
      billNumber: billNumber,
      storeLabel: storeLabel,
    );

    return jsonSuccess(result, statusCode: HttpStatus.created, message: 'Bakong KHQR generated');
  } catch (e) {
    return jsonError(e.toString());
  }
}
