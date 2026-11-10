import 'package:fixnum/fixnum.dart';
import 'package:my_api/services/bakong_service.dart';
import 'package:my_api/utils/helpers.dart';
import 'package:test/test.dart';

void main() {
  group('BakongService', () {
    test('calculateCrc16 accurately computes EMVCo CCITT CRC-16', () {
      const testStr =
          '00020101021229180014jonhsmith@nbcq52045999530311654035005802KH5910Jonh Smith6010PHNOM PENH9917001317394957787226304';
      final crc = BakongService.calculateCrc16(testStr)
          .toRadixString(16)
          .toUpperCase()
          .padLeft(4, '0');
      expect(crc, equals('6894'));
    });

    test('checkAccount verifies user Bakong Account ID on live Bakong API', () async {
      final res = await BakongService.checkAccount('lyhav_voeurn@bkrt');
      expect(res['responseCode'], equals(0));
      expect(res['data']?['fullName'], equals('LYHAV VOEURN'));
      expect(res['data']?['canReceive'], equals(true));
    });

    test('createKhqrPayment generates valid KHQR payload and deeplink', () async {
      final res = await BakongService.createKhqrPayment(
        amount: 4000,
        currency: 'KHR',
        billNumber: 'TEST-ORD-001',
      );

      expect(res['qrString'], isNotNull);
      expect(res['qrImageUrl'], isNotNull);
      expect(res['qrString'].toString().startsWith('000201010212'), isTrue);
      expect(res['md5'], isNotNull);
      expect(res['md5'].toString().length, equals(32));
      expect(res['shortLink'], isNotNull);
      expect(res['shortLink'].toString().startsWith('https://bakong-deeplink.nbc.gov.kh'), isTrue);
    });

    test('checkTransactionByMd5 queries transaction state', () async {
      final res = await BakongService.checkTransactionByMd5('00000000000000000000000000000000');
      expect(res['responseCode'], equals(1));
      expect(res['isPaid'], isFalse);
    });

    test('cleanDoc and jsonSuccess safely serialize Int64 timestamps', () {
      final dataWithInt64 = {
        'status': 'paid',
        'createdDateMs': Int64(1794250435000),
        'nested': {
          'count': Int64(100),
        },
      };
      final res = jsonSuccess(dataWithInt64);
      expect(res.statusCode, equals(200));
    });
  });
}
