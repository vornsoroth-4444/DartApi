import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/database/database.dart';
import 'package:my_api/utils/helpers.dart';

class ProductService {
  static Future<Map<String, dynamic>> listProducts({
    String? category,
    String? brand,
    double? minPrice,
    double? maxPrice,
    String? sort,
    int page = 1,
    int limit = 20,
  }) async {
    await Database.ensureConnected();
    final query = <String, dynamic>{};

    if (category != null && category.isNotEmpty) {
      query[r'$or'] = [
        {'categoryId': category},
        {'category': RegExp(category, caseSensitive: false)},
      ];
    }

    if (brand != null && brand.isNotEmpty) {
      query['brand'] = RegExp(brand, caseSensitive: false);
    }

    if (minPrice != null || maxPrice != null) {
      final priceFilter = <String, dynamic>{};
      if (minPrice != null) priceFilter[r'$gte'] = minPrice;
      if (maxPrice != null) priceFilter[r'$lte'] = maxPrice;
      query['price'] = priceFilter;
    }

    var selector = where;
    for (final entry in query.entries) {
      selector = selector.eq(entry.key, entry.value);
    }

    if (sort == 'price-asc') {
      selector = selector.sortBy('price');
    } else if (sort == 'price-desc') {
      selector = selector.sortBy('price', descending: true);
    } else if (sort == 'rating') {
      selector = selector.sortBy('rating', descending: true);
    } else {
      selector = selector.sortBy('createdAt', descending: true);
    }

    final skip = (page - 1) * limit;
    final total = await Database.products.count(query);
    final rawDocs = await Database.products.find(selector.skip(skip).limit(limit)).toList();

    return {
      'products': cleanDocs(rawDocs),
      'pagination': {
        'total': total,
        'page': page,
        'limit': limit,
        'totalPages': (total / limit).ceil(),
      },
    };
  }

  static Future<Map<String, dynamic>?> _findProductRaw(String idOrSlug) async {
    await Database.ensureConnected();
    final parsed = parseId(idOrSlug);
    Map<String, dynamic>? doc;

    if (parsed is ObjectId) {
      doc = await Database.products.findOne(where.eq('_id', parsed));
    }

    doc ??= await Database.products.findOne(where.eq('slug', idOrSlug));
    doc ??= await Database.products.findOne(where.eq('id', idOrSlug));
    doc ??= await Database.products.findOne(where.eq('_id', idOrSlug));

    return doc;
  }

  static Future<Map<String, dynamic>?> getProduct(String idOrSlug) async {
    final doc = await _findProductRaw(idOrSlug);
    return cleanDoc(doc);
  }

  static Future<List<Map<String, dynamic>>> getNewArrivals({int limit = 10}) async {
    await Database.ensureConnected();
    final raw = await Database.products
        .find(where.eq('isNew', true).sortBy('createdAt', descending: true).limit(limit))
        .toList();
    return cleanDocs(raw);
  }

  static Future<List<Map<String, dynamic>>> getFlashDeals() async {
    await Database.ensureConnected();
    final raw = await Database.products
        .find(where.eq('flashSale.active', true).sortBy('flashSale.discountPercentage', descending: true))
        .toList();
    return cleanDocs(raw);
  }

  static Future<List<Map<String, dynamic>>> search(String query) async {
    await Database.ensureConnected();
    final regex = RegExp(query, caseSensitive: false);
    final raw = await Database.products.find({
      r'$or': [
        {'name': regex},
        {'brand': regex},
        {'category': regex},
        {'tags': regex},
        {'description': regex},
      ],
    }).toList();
    return cleanDocs(raw);
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    await Database.ensureConnected();
    final categories = await Database.categories.find().toList();
    final result = <Map<String, dynamic>>[];

    for (final cat in categories) {
      final slug = cat['slug']?.toString() ?? cat['id']?.toString() ?? '';
      final count = await Database.products.count({
        r'$or': [
          {'categoryId': slug},
          {'category': RegExp(slug, caseSensitive: false)},
        ],
      });
      final cleaned = cleanDoc(cat)!;
      cleaned['productCount'] = count;
      result.add(cleaned);
    }
    return result;
  }

  static Future<Map<String, dynamic>> getCategoryProducts(
    String categoryId, {
    int page = 1,
    int limit = 20,
  }) async {
    return listProducts(category: categoryId, page: page, limit: limit);
  }

  static Future<Map<String, dynamic>?> getBrand(String slug) async {
    await Database.ensureConnected();
    final brandDoc = await Database.brands.findOne(
      where.eq('slug', slug.toLowerCase()),
    );
    if (brandDoc == null) return null;

    final products = await Database.products
        .find(where.eq('brandSlug', slug.toLowerCase()))
        .toList();

    final result = cleanDoc(brandDoc)!;
    result['products'] = cleanDocs(products);
    return result;
  }

  static Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    await Database.ensureConnected();

    final name = (data['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      throw const FormatException('Product name is required');
    }

    if (data['price'] == null) {
      throw const FormatException('Product price is required');
    }
    final price = parseDouble(data['price']);
    if (price < 0) {
      throw const FormatException('Product price cannot be negative');
    }

    final category = (data['category'] ?? '').toString().trim();
    final brand = (data['brand'] ?? '').toString().trim();

    var slug = (data['slug'] ?? '').toString().trim();
    if (slug.isEmpty) {
      slug = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    }

    final existing = await Database.products.findOne(where.eq('slug', slug));
    if (existing != null) {
      slug = '$slug-${DateTime.now().millisecondsSinceEpoch % 10000}';
    }

    final images = data['images'] is List
        ? (data['images'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final thumbnail = data['thumbnail']?.toString() ?? (images.isNotEmpty ? images.first : null);

    final now = DateTime.now().toUtc();
    final doc = {
      '_id': ObjectId(),
      'name': name,
      'slug': slug,
      'description': data['description']?.toString().trim() ?? '',
      'price': price,
      if (data['compareAtPrice'] != null) 'compareAtPrice': parseDouble(data['compareAtPrice']),
      'category': category,
      'categoryId': data['categoryId']?.toString() ?? category.toLowerCase().replaceAll(' ', '-'),
      'brand': brand,
      'brandSlug': data['brandSlug']?.toString() ?? brand.toLowerCase().replaceAll(' ', '-'),
      'images': images,
      if (thumbnail != null) 'thumbnail': thumbnail,
      'stock': parseInt(data['stock'], 0),
      'isNew': data['isNew'] == true || data['isNew'] == null,
      'rating': parseDouble(data['rating'], 0.0),
      'reviewCount': parseInt(data['reviewCount'], 0),
      'colors': data['colors'] is List ? (data['colors'] as List).map((e) => e.toString()).toList() : <String>[],
      'sizes': data['sizes'] is List ? (data['sizes'] as List).map((e) => e.toString()).toList() : <String>[],
      'tags': data['tags'] is List ? (data['tags'] as List).map((e) => e.toString()).toList() : <String>[],
      if (data['flashSale'] is Map) 'flashSale': data['flashSale'],
      'createdAt': now,
      'updatedAt': now,
    };

    await Database.products.insertOne(doc);
    return cleanDoc(doc)!;
  }

  static Future<Map<String, dynamic>?> updateProduct(
    String idOrSlug,
    Map<String, dynamic> data,
  ) async {
    await Database.ensureConnected();

    final existing = await _findProductRaw(idOrSlug);
    if (existing == null) {
      return null;
    }

    final targetId = existing['_id'];
    final modifier = modify.set('updatedAt', DateTime.now().toUtc());

    if (data.containsKey('name')) {
      final name = data['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        throw const FormatException('Product name cannot be empty');
      }
      modifier.set('name', name);
    }

    if (data.containsKey('price')) {
      if (data['price'] == null) {
        throw const FormatException('Product price cannot be null');
      }
      final price = parseDouble(data['price']);
      if (price < 0) {
        throw const FormatException('Product price cannot be negative');
      }
      modifier.set('price', price);
    }

    if (data.containsKey('compareAtPrice')) {
      modifier.set(
        'compareAtPrice',
        data['compareAtPrice'] != null ? parseDouble(data['compareAtPrice']) : null,
      );
    }

    if (data.containsKey('description')) {
      modifier.set('description', data['description']?.toString().trim() ?? '');
    }

    if (data.containsKey('category')) {
      final category = data['category']?.toString().trim() ?? '';
      modifier.set('category', category);
      if (!data.containsKey('categoryId')) {
        modifier.set('categoryId', category.toLowerCase().replaceAll(' ', '-'));
      }
    }

    if (data.containsKey('categoryId')) {
      modifier.set('categoryId', data['categoryId']?.toString().trim() ?? '');
    }

    if (data.containsKey('brand')) {
      final brand = data['brand']?.toString().trim() ?? '';
      modifier.set('brand', brand);
      if (!data.containsKey('brandSlug')) {
        modifier.set('brandSlug', brand.toLowerCase().replaceAll(' ', '-'));
      }
    }

    if (data.containsKey('brandSlug')) {
      modifier.set('brandSlug', data['brandSlug']?.toString().trim() ?? '');
    }

    if (data.containsKey('slug')) {
      var slug = data['slug']?.toString().trim() ?? '';
      if (slug.isNotEmpty) {
        final existingWithSlug = await Database.products.findOne(
          where.eq('slug', slug).ne('_id', targetId),
        );
        if (existingWithSlug != null) {
          slug = '$slug-${DateTime.now().millisecondsSinceEpoch % 10000}';
        }
        modifier.set('slug', slug);
      }
    }

    if (data.containsKey('images')) {
      final images = data['images'] is List
          ? (data['images'] as List).map((e) => e.toString()).toList()
          : <String>[];
      modifier.set('images', images);
      if (!data.containsKey('thumbnail') && images.isNotEmpty) {
        modifier.set('thumbnail', images.first);
      }
    }

    if (data.containsKey('thumbnail')) {
      modifier.set('thumbnail', data['thumbnail']?.toString());
    }

    if (data.containsKey('stock')) {
      if (data['stock'] == null) {
        throw const FormatException('Product stock cannot be null');
      }
      final stock = parseInt(data['stock']);
      if (stock < 0) {
        throw const FormatException('Product stock cannot be negative');
      }
      modifier.set('stock', stock);
    }

    if (data.containsKey('isNew')) {
      modifier.set('isNew', data['isNew'] == true);
    }

    if (data.containsKey('rating')) {
      modifier.set('rating', parseDouble(data['rating'], 0.0));
    }

    if (data.containsKey('reviewCount')) {
      modifier.set('reviewCount', parseInt(data['reviewCount'], 0));
    }

    if (data.containsKey('colors')) {
      final colors = data['colors'] is List
          ? (data['colors'] as List).map((e) => e.toString()).toList()
          : <String>[];
      modifier.set('colors', colors);
    }

    if (data.containsKey('sizes')) {
      final sizes = data['sizes'] is List
          ? (data['sizes'] as List).map((e) => e.toString()).toList()
          : <String>[];
      modifier.set('sizes', sizes);
    }

    if (data.containsKey('tags')) {
      final tags = data['tags'] is List
          ? (data['tags'] as List).map((e) => e.toString()).toList()
          : <String>[];
      modifier.set('tags', tags);
    }

    if (data.containsKey('flashSale')) {
      modifier.set('flashSale', data['flashSale'] is Map ? data['flashSale'] : null);
    }

    await Database.products.updateOne(where.eq('_id', targetId), modifier);

    final updated = await Database.products.findOne(where.eq('_id', targetId));
    return cleanDoc(updated);
  }

  static Future<bool> deleteProduct(String idOrSlug) async {
    await Database.ensureConnected();
    final existing = await _findProductRaw(idOrSlug);
    if (existing == null) {
      return false;
    }
    await Database.products.remove(where.eq('_id', existing['_id']));
    return true;
  }
}

class ProductController {
  static Future<Response> list(RequestContext context) async {
    final params = context.request.uri.queryParameters;
    final category = params['category'];
    final brand = params['brand'];
    final minPrice = double.tryParse(params['minPrice'] ?? '');
    final maxPrice = double.tryParse(params['maxPrice'] ?? '');
    final sort = params['sort'];
    final page = int.tryParse(params['page'] ?? '1') ?? 1;
    final limit = int.tryParse(params['limit'] ?? '20') ?? 20;

    final data = await ProductService.listProducts(
      category: category,
      brand: brand,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sort: sort,
      page: page,
      limit: limit,
    );
    return jsonSuccess(data);
  }

  static Future<Response> detail(RequestContext context, String id) async {
    final product = await ProductService.getProduct(id);
    if (product == null) {
      return jsonError('Product not found', statusCode: HttpStatus.notFound);
    }
    return jsonSuccess(product);
  }

  static Future<Response> newArrivals(RequestContext context) async {
    final products = await ProductService.getNewArrivals();
    return jsonSuccess(products);
  }

  static Future<Response> flashDeals(RequestContext context) async {
    final products = await ProductService.getFlashDeals();
    return jsonSuccess(products);
  }

  static Future<Response> search(RequestContext context) async {
    final q = context.request.uri.queryParameters['q'] ?? '';
    if (q.trim().isEmpty) {
      return jsonSuccess(<Map<String, dynamic>>[]);
    }
    final products = await ProductService.search(q.trim());
    return jsonSuccess(products);
  }

  static Future<Response> categories(RequestContext context) async {
    final list = await ProductService.getCategories();
    return jsonSuccess(list);
  }

  static Future<Response> categoryProducts(RequestContext context, String id) async {
    final params = context.request.uri.queryParameters;
    final page = int.tryParse(params['page'] ?? '1') ?? 1;
    final limit = int.tryParse(params['limit'] ?? '20') ?? 20;

    final data = await ProductService.getCategoryProducts(id, page: page, limit: limit);
    return jsonSuccess(data);
  }

  static Future<Response> brand(RequestContext context, String slug) async {
    final data = await ProductService.getBrand(slug);
    if (data == null) {
      return jsonError('Brand not found', statusCode: HttpStatus.notFound);
    }
    return jsonSuccess(data);
  }

  static Future<Response> create(RequestContext context) async {
    try {
      final body = await readJsonBody(context);
      final product = await ProductService.createProduct(body);
      return jsonSuccess(product, statusCode: HttpStatus.created, message: 'Product created');
    } catch (e) {
      return jsonError(e.toString().replaceAll('FormatException: ', ''));
    }
  }

  static Future<Response> update(RequestContext context, String id) async {
    try {
      final body = await readJsonBody(context);
      final product = await ProductService.updateProduct(id, body);
      if (product == null) {
        return jsonError('Product not found', statusCode: HttpStatus.notFound);
      }
      return jsonSuccess(product, message: 'Product updated');
    } catch (e) {
      return jsonError(e.toString().replaceAll('FormatException: ', ''));
    }
  }

  static Future<Response> delete(RequestContext context, String id) async {
    try {
      final deleted = await ProductService.deleteProduct(id);
      if (!deleted) {
        return jsonError('Product not found', statusCode: HttpStatus.notFound);
      }
      return jsonSuccess({'id': id}, message: 'Product deleted');
    } catch (e) {
      return jsonError(e.toString().replaceAll('FormatException: ', ''));
    }
  }
}
