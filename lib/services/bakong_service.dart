import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class BakongService {
  static String get apiUrl =>
      Platform.environment['BAKONG_API_URL'] ?? 'https://api-bakong.nbc.gov.kh';

  static String get token =>
      Platform.environment['BAKONG_TOKEN'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7ImlkIjoiYzYzODg2ZmFkNmMzNDZjMSJ9LCJpYXQiOjE3OTMzMjk1MDksImV4cCI6MTgwMTEwNTUwOX0.tqT1iokunIWHKBMGOe57XdZSDC0Az_RXRLCF68NplcI';

  static String get accountId =>
      Platform.environment['BAKONG_ACCOUNT_ID'] ?? 'lyhav_voeurn@bkrt';

  static String get merchantName =>
      Platform.environment['BAKONG_MERCHANT_NAME'] ?? 'LYHAV VOEURN';

  static String get phoneNumber =>
      Platform.environment['BAKONG_PHONE_NUMBER'] ?? '067687806';

  static String get defaultCurrency =>
      Platform.environment['KHQR_CURRENCY'] ?? 'KHR';

  static String get country =>
      Platform.environment['KHQR_COUNTRY'] ?? 'KH';

  static String get city =>
      Platform.environment['KHQR_CITY'] ?? 'Phnom Penh';

  /// Standard EMVCo TLV (Tag-Length-Value) formatting
  static String formatTlv(String tag, String value) {
    final length = utf8.encode(value).length.toString().padLeft(2, '0');
    return '$tag$length$value';
  }

  /// CRC-16/CCITT-FALSE algorithm (Polynomial: 0x1021, Initial value: 0xFFFF)
  static int calculateCrc16(String input) {
    int crc = 0xFFFF;
    final bytes = utf8.encode(input);
    for (final b in bytes) {
      crc ^= (b << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }

  /// Calculates MD5 hash of the raw KHQR string
  static String getMd5(String rawQr) {
    return md5.convert(utf8.encode(rawQr)).toString();
  }

  /// Generates an EMVCo compliant Dynamic Bakong KHQR String
  static String buildKhqrString({
    required double amount,
    required String billNumber,
    String? currency,
    String? mobileNumber,
    String? storeLabel,
  }) {
    final cur = (currency ?? defaultCurrency).toUpperCase();
    final isKhr = cur == 'KHR';
    final currencyCode = isKhr ? '116' : '840';

    // Amount formatting: KHR is integer without decimals; USD formatted to 2 decimals
    final formattedAmount = isKhr ? amount.round().toString() : amount.toStringAsFixed(2);

    final raw = StringBuffer()
      ..write(formatTlv('00', '01')) // Payload Format Indicator
      ..write(formatTlv('01', '12')); // Point of Initiation Method: 12 = Dynamic

    // Tag 29: Merchant Account Information (Remittance / Solo Individual)
    final tag29Buffer = StringBuffer()
      ..write(formatTlv('00', accountId));
    final phone = mobileNumber ?? phoneNumber;
    if (phone.isNotEmpty) {
      tag29Buffer.write(formatTlv('01', phone));
    }
    tag29Buffer.write(formatTlv('02', 'Bakong'));
    raw.write(formatTlv('29', tag29Buffer.toString()));

    // Tag 52: Merchant Category Code (MCC)
    raw.write(formatTlv('52', '5999'));

    // Tag 53: Transaction Currency (116 = KHR, 840 = USD)
    raw.write(formatTlv('53', currencyCode));

    // Tag 54: Transaction Amount
    raw.write(formatTlv('54', formattedAmount));

    // Tag 58: Country Code
    raw.write(formatTlv('58', country));

    // Tag 59: Merchant Name
    raw.write(formatTlv('59', merchantName));

    // Tag 60: Merchant City
    raw.write(formatTlv('60', city));

    // Tag 62: Additional Data Field Template
    final tag62Buffer = StringBuffer();
    tag62Buffer.write(formatTlv('01', billNumber));
    if (phone.isNotEmpty) {
      tag62Buffer.write(formatTlv('02', phone));
    }
    if (storeLabel != null && storeLabel.isNotEmpty) {
      tag62Buffer.write(formatTlv('03', storeLabel));
    }
    raw.write(formatTlv('62', tag62Buffer.toString()));

    // Tag 99: Creation and Expiration Timestamps (Required for dynamic amounts)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expireMs = nowMs + 15 * 60 * 1000; // 15 minutes expiration
    final tag99Buffer = StringBuffer()
      ..write(formatTlv('00', nowMs.toString()))
      ..write(formatTlv('01', expireMs.toString()));
    raw.write(formatTlv('99', tag99Buffer.toString()));

    // Tag 63: CRC placeholder
    final preCrc = '${raw}6304';
    final crcVal = calculateCrc16(preCrc).toRadixString(16).toUpperCase().padLeft(4, '0');

    return '$preCrc$crcVal';
  }

  /// Generate Deeplink via official Bakong Open API
  static Future<Map<String, dynamic>?> generateDeeplink({
    required String qrString,
    String appName = 'E-Commerce Store',
    String appIconUrl = 'https://bakong.nbc.gov.kh/images/logo.png',
    String? callbackUrl,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$apiUrl/v1/generate_deeplink_by_qr'));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $token');

      final body = jsonEncode({
        'qr': qrString,
        'sourceInfo': {
          'appName': appName,
          'appIconUrl': appIconUrl,
          if (callbackUrl != null) 'appDeepLinkCallBack': callbackUrl,
        },
      });

      request.write(body);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == HttpStatus.ok) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        if (json['responseCode'] == 0 && json['data'] != null) {
          return json['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Full Bakong KHQR generation with MD5 and Deeplink
  static Future<Map<String, dynamic>> createKhqrPayment({
    required double amount,
    required String billNumber,
    String? currency,
    String? storeLabel,
    String appName = 'E-Commerce App',
  }) async {
    final cur = (currency ?? defaultCurrency).toUpperCase();
    final qrString = buildKhqrString(
      amount: amount,
      currency: cur,
      billNumber: billNumber,
      storeLabel: storeLabel,
    );

    final md5Hash = getMd5(qrString);

    // Call Bakong API to obtain shortLink deeplink
    final deeplinkData = await generateDeeplink(
      qrString: qrString,
      appName: appName,
    );

    final qrImageUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=${Uri.encodeComponent(qrString)}';

    return {
      'qrString': qrString,
      'qrImageUrl': qrImageUrl,
      'md5': md5Hash,
      'amount': cur == 'KHR' ? amount.round() : amount,
      'currency': cur,
      'accountId': accountId,
      'merchantName': merchantName,
      'billNumber': billNumber,
      'shortLink': deeplinkData?['shortLink'],
      'fullLink': deeplinkData?['fullLink'],
    };
  }

  /// Check payment transaction status using MD5 hash via Bakong API
  ///
  /// Response:
  /// - `isPaid`: true if transaction has completed and money was deducted from customer's bank
  /// - `responseCode`: 0 = Success (Paid), 1 = Transaction not found (Pending)
  static Future<Map<String, dynamic>> checkTransactionByMd5(String md5Hash) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$apiUrl/v1/check_transaction_by_md5'));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $token');

      final body = jsonEncode({'md5': md5Hash});
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Bakong API returned HTTP ${response.statusCode}: $responseBody',
        );
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final responseCode = json['responseCode'];
      final isPaid = responseCode == 0;

      return {
        'isPaid': isPaid,
        'responseCode': responseCode,
        'responseMessage': json['responseMessage'],
        'data': json['data'],
      };
    } finally {
      client.close();
    }
  }

  /// Verify active status of a Bakong Account ID
  static Future<Map<String, dynamic>> checkAccount(String account) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$apiUrl/v1/check_bakong_account'));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $token');

      final body = jsonEncode({'accountId': account});
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
}
