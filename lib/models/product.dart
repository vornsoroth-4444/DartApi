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

  final String id;
  final String name;
  final String slug;
  final String description;
  final double price;
  final double? compareAtPrice;
  final String category;
  final String brand;
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
        'brand': brand,
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
