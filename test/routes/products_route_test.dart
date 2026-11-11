import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/controllers/product_controller.dart';
import 'package:my_api/database/database.dart';
import 'package:test/test.dart';

import '../../routes/api/v1/products/[id]/index.dart' as id_route;
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

  group('PUT & PATCH /api/v1/products/[id]', () {
    late Map<String, dynamic> testProduct;

    setUp(() async {
      testProduct = await ProductService.createProduct({
        'name': 'Update Test Hoodie',
        'price': 49.99,
        'category': 'Fashion & Apparel',
        'brand': 'Adidas',
        'stock': 15,
      });
    });

    tearDown(() async {
      final id = testProduct['id']?.toString() ?? testProduct['_id']?.toString();
      if (id != null) {
        await Database.products.remove(where.eq('name', 'Update Test Hoodie'));
        await Database.products.remove(where.eq('name', 'Fully Updated Hoodie'));
      }
    });

    test('updates a product via HTTP PUT endpoint', () async {
      final context = _MockRequestContext();
      final request = _MockRequest();
      final productId = testProduct['id'].toString();

      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.put);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({
          'name': 'Fully Updated Hoodie',
          'price': 59.99,
          'stock': 20,
        }),
      );

      final response = await id_route.onRequest(context, productId);
      expect(response.statusCode, equals(HttpStatus.ok));

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['message'], equals('Product updated'));
      expect(body['name'], equals('Fully Updated Hoodie'));
      expect(body['price'], equals(59.99));
      expect(body['stock'], equals(20));
    });

    test('partially updates a product via HTTP PATCH endpoint', () async {
      final context = _MockRequestContext();
      final request = _MockRequest();
      final productId = testProduct['id'].toString();

      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.patch);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({
          'price': 39.99,
        }),
      );

      final response = await id_route.onRequest(context, productId);
      expect(response.statusCode, equals(HttpStatus.ok));

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['price'], equals(39.99));
      expect(body['name'], equals('Update Test Hoodie'));
    });

    test('returns 404 Not Found when updating non-existent product', () async {
      final context = _MockRequestContext();
      final request = _MockRequest();
      final fakeId = ObjectId().oid;

      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.patch);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({
          'name': 'Does Not Exist',
        }),
      );

      final response = await id_route.onRequest(context, fakeId);
      expect(response.statusCode, equals(HttpStatus.notFound));

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['success'], isFalse);
      expect(body['error'], equals('Product not found'));
    });

    test('returns 400 Bad Request when update has invalid price', () async {
      final context = _MockRequestContext();
      final request = _MockRequest();
      final productId = testProduct['id'].toString();

      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.put);
      when(() => request.body()).thenAnswer(
        (_) async => jsonEncode({
          'price': -15.0,
        }),
      );

      final response = await id_route.onRequest(context, productId);
      expect(response.statusCode, equals(HttpStatus.badRequest));

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['success'], isFalse);
      expect(body['error'], contains('price cannot be negative'));
    });
  });

  group('DELETE /api/v1/products/[id]', () {
    test('deletes a product via HTTP DELETE endpoint', () async {
      final product = await ProductService.createProduct({
        'name': 'Delete Test Product',
        'price': 19.99,
        'category': 'Electronics',
        'brand': 'Sony',
        'stock': 5,
      });

      final context = _MockRequestContext();
      final request = _MockRequest();
      final productId = product['id'].toString();

      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.delete);

      final response = await id_route.onRequest(context, productId);
      expect(response.statusCode, equals(HttpStatus.ok));

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['message'], equals('Product deleted'));
      expect(body['id'], equals(productId));

      final fetched = await ProductService.getProduct(productId);
      expect(fetched, isNull);
    });

    test('returns 404 Not Found when deleting non-existent product', () async {
      final context = _MockRequestContext();
      final request = _MockRequest();
      final fakeId = ObjectId().oid;

      when(() => context.request).thenReturn(request);
      when(() => request.method).thenReturn(HttpMethod.delete);

      final response = await id_route.onRequest(context, fakeId);
      expect(response.statusCode, equals(HttpStatus.notFound));

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['success'], isFalse);
      expect(body['error'], equals('Product not found'));
    });
  });
}
