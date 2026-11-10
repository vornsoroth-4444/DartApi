class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.price,
    required this.category,
    required this.brand,
    required this.images,
    required this.stock,
    this.categoryId,
    this.brandSlug,
    this.compareAtPrice,
    this.thumbnail,
    this.isNew = false,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.colors = const [],
    this.sizes = const [],
    this.tags = const [],
    this.flashSale,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
        category: json['category']?.toString() ?? '',
        categoryId: json['categoryId']?.toString(),
        brand: json['brand']?.toString() ?? '',
        brandSlug: json['brandSlug']?.toString(),
        images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        thumbnail: json['thumbnail']?.toString(),
        stock: (json['stock'] as num?)?.toInt() ?? 0,
        isNew: json['isNew'] == true,
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        colors: (json['colors'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        sizes: (json['sizes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        flashSale: json['flashSale'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['flashSale'] as Map)
            : null,
      );

  final String id;
  final String name;
  final String slug;
  final String description;
  final double price;
  final double? compareAtPrice;
  final String category;
  final String? categoryId;
  final String brand;
  final String? brandSlug;
  final List<String> images;
  final String? thumbnail;
  final int stock;
  final bool isNew;
  final double rating;
  final int reviewCount;
  final List<String> colors;
  final List<String> sizes;
  final List<String> tags;
  final Map<String, dynamic>? flashSale;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'price': price,
        'compareAtPrice': compareAtPrice,
        'category': category,
        if (categoryId != null) 'categoryId': categoryId,
        'brand': brand,
        if (brandSlug != null) 'brandSlug': brandSlug,
        'images': images,
        'thumbnail': thumbnail,
        'stock': stock,
        'isNew': isNew,
        'rating': rating,
        'reviewCount': reviewCount,
        'colors': colors,
        'sizes': sizes,
        'tags': tags,
        'flashSale': flashSale,
      };
}
