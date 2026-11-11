import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/controllers/auth_controller.dart';
import 'package:my_api/controllers/cart_controller.dart';
import 'package:my_api/controllers/order_controller.dart';
import 'package:my_api/controllers/product_controller.dart';
import 'package:my_api/controllers/voucher_controller.dart';
import 'package:my_api/database/database.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    await Database.connect();
  });

  tearDownAll(() async {
    await Database.close();
  });

  group('Authentication Service', () {
    test('Logs in default user with correct credentials', () async {
      final result =
          await AuthService.login('vornsoroth@gmail.com', 'Password123!');
      expect(result['token'], isNotNull);
      expect(result['user'], isNotNull);
      expect(result['user']['email'], equals('vornsoroth@gmail.com'));
      expect(result['user']['name'], equals('soroth'));
    });

    test('Rejects invalid password', () async {
      expect(
        () => AuthService.login('vornsoroth@gmail.com', 'WrongPassword!'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Product Catalog Service', () {
    test('Lists seeded products', () async {
      final result = await ProductService.listProducts();
      final products = result['products'] as List;
      expect(products, isNotEmpty);
      expect(products.length, greaterThanOrEqualTo(5));
    });

    test('Fetches categories with product counts', () async {
      final categories = await ProductService.getCategories();
      expect(categories, isNotEmpty);
      expect(categories.any((c) => c['slug'] == 'footwear'), isTrue);
    });

    test('Fetches new arrivals and flash deals', () async {
      final newArrivals = await ProductService.getNewArrivals();
      expect(newArrivals, isNotEmpty);

      final flashDeals = await ProductService.getFlashDeals();
      expect(flashDeals, isNotEmpty);
    });

    test('Creates a new product', () async {
      final product = await ProductService.createProduct({
        'name': 'Nike Air Zoom Pegasus Test',
        'price': 129.99,
        'category': 'Footwear',
        'brand': 'Nike',
        'stock': 50,
        'images': [
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff',
        ],
      });

      expect(product['id'], isNotNull);
      expect(product['name'], equals('Nike Air Zoom Pegasus Test'));
      expect(product['price'], equals(129.99));
      expect(product['stock'], equals(50));

      final fetched = await ProductService.getProduct(product['id'].toString());
      expect(fetched, isNotNull);
      expect(fetched?['name'], equals('Nike Air Zoom Pegasus Test'));

      await Database.products.remove(where.eq('name', 'Nike Air Zoom Pegasus Test'));
    });

    test('Rejects product creation with missing name or invalid price', () async {
      expect(
        () => ProductService.createProduct({'price': 50.0}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ProductService.createProduct({'name': 'Missing Price'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ProductService.createProduct({'name': 'Negative Price', 'price': -10.0}),
        throwsA(isA<FormatException>()),
      );
    });

    test('Updates an existing product', () async {
      final product = await ProductService.createProduct({
        'name': 'Service Update Test Product',
        'price': 45.0,
        'category': 'Electronics',
        'brand': 'Sony',
        'stock': 10,
      });

      final productId = product['id'].toString();
      final updated = await ProductService.updateProduct(productId, {
        'name': 'Service Update Test Product Renamed',
        'price': 49.99,
        'stock': 15,
      });

      expect(updated, isNotNull);
      expect(updated?['name'], equals('Service Update Test Product Renamed'));
      expect(updated?['price'], equals(49.99));
      expect(updated?['stock'], equals(15));

      await ProductService.deleteProduct(productId);
    });

    test('Deletes an existing product', () async {
      final product = await ProductService.createProduct({
        'name': 'Service Delete Test Product',
        'price': 30.0,
        'category': 'Sports',
        'brand': 'Adidas',
        'stock': 5,
      });

      final productId = product['id'].toString();
      final deleted = await ProductService.deleteProduct(productId);
      expect(deleted, isTrue);

      final fetched = await ProductService.getProduct(productId);
      expect(fetched, isNull);

      final deleteAgain = await ProductService.deleteProduct(productId);
      expect(deleteAgain, isFalse);
    });
  });

  group('Cart & Voucher Service', () {
    test('Validates and calculates voucher discount', () async {
      final voucherResult = await VoucherService.applyVoucher('WELCOME10', 100.0);
      expect(voucherResult['valid'], isTrue);
      expect(voucherResult['discountAmount'], equals(10.0));
      expect(voucherResult['newTotal'], equals(90.0));
    });
  });

  group('Bakong KHQR Checkout Service', () {
    test('Checkout with khqr returns ready-to-scan QR code details', () async {
      final auth = await AuthService.login('vornsoroth@gmail.com', 'Password123!');
      final userId = auth['user']['id'].toString();

      final products = await ProductService.listProducts();
      final product = (products['products'] as List).first as Map;
      await CartService.addItem(
        userId: userId,
        productId: product['id'].toString(),
        quantity: 1,
      );

      final order = await OrderService.checkout(
        userId: userId,
        paymentType: 'khqr',
      );

      expect(order['status'], equals('pending_payment'));
      expect(order['khqr'], isNotNull);
      expect(order['khqr']['qrImageUrl'], isNotNull);
      expect(order['khqr']['qrImageUrl'].toString().startsWith('https://'), isTrue);
      expect(order['khqr']['qrString'], isNotNull);
      expect(order['khqr']['shortLink'], isNotNull);
      expect(order['khqr']['md5'], isNotNull);
    });
  });
}
