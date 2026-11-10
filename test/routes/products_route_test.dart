import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:test/test.dart';

import '../../routes/api/v1/products/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

void main() {
  setUpAll(() async {
    await Database.connect();
  });

  tearDownAll(() async {
    await Database.close();
  });

  group('POST /api/v1/products', () {
    test('creates a product via HTTP POST endpoint', () async {
      final context = _MockRequestContext();
      final request = _MockRequest();

      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({
          'name': 'Route Test Jacket',
          'price': 89.5,
          'category': 'Fashion & Apparel',
          'brand': 'Zara',
          'stock': 12,
        }),
      );

      final response = await route.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.created));

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['name'], equals('Route Test Jacket'));
      expect(body['price'], equals(89.5));
      expect(body['brandSlug'], equals('zara'));

      await Database.products.remove(where.eq('name', 'Route Test Jacket'));
    });

    test('returns 400 Bad Request when name is missing', () async {
      final context = _MockRequestContext();
      final request = _MockRequest();

      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({
          'price': 25.0,
        }),
      );

      final response = await route.onRequest(context);
      expect(response.statusCode, equals(HttpStatus.badRequest));

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['success'], isFalse);
      expect(body['error'], contains('name is required'));
    });
  });
}
