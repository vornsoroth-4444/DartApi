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

    // Sort order
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

  static Future<Map<String, dynamic>?> getProduct(String idOrSlug) async {
    await Database.ensureConnected();
    final parsed = parseId(idOrSlug);
    Map<String, dynamic>? doc;

    if (parsed is ObjectId) {
      doc = await Database.products.findOne(where.eq('_id', parsed));
    }

    doc ??= await Database.products.findOne(where.eq('slug', idOrSlug));
    doc ??= await Database.products.findOne(where.eq('id', idOrSlug));

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
}
