import 'package:mongo_dart/mongo_dart.dart';
import 'package:my_api/utils/hash_utils.dart';
import 'database.dart';

class DatabaseSeeder {
  static Future<void> seedIfEmpty() async {
    await _ensureDefaultUser();
    final count = await Database.products.count();
    if (count > 0) return;
    await seedAll();
  }

  static Future<void> _ensureDefaultUser() async {
    const cleanEmail = 'vornsoroth@gmail.com';
    final existing =
        await Database.users.findOne(where.eq('email', cleanEmail));
    final salt = HashUtils.generateSalt();
    final hash = HashUtils.hashPassword('Password123!', salt);
    final now = DateTime.now().toUtc();

    if (existing == null) {
      final userId = ObjectId();

      await Database.users.insertOne({
        '_id': userId,
        'email': cleanEmail,
        'name': 'soroth',
        'passwordHash': hash,
        'salt': salt,
        'phone': '+1 (555) 019-2834',
        'dob': '1995-04-12',
        'avatar':
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
        'provider': 'local',
        'referralCode': 'SOROTH2026',
        'loyaltyPoints': 250,
        'loyaltyTier': 'Gold',
        'createdAt': now,
        'updatedAt': now,
      });

      await Database.notificationSettings.insertOne({
        '_id': ObjectId(),
        'userId': userId.oid,
        'orderUpdates': true,
        'promotions': true,
        'priceAlerts': true,
        'inAppNotifications': true,
        'emailNotifications': true,
        'smsNotifications': false,
        'updatedAt': now,
      });
    } else {
      await Database.users.updateOne(
        where.eq('email', cleanEmail),
        modify
            .set('name', 'soroth')
            .set('phone', '012345678')
            .set('passwordHash', hash)
            .set('salt', salt)
            .set('updatedAt', now),
      );
    }
  }

  static Future<void> seedAll() async {
    final now = DateTime.now().toUtc();

    final demoUserId = ObjectId();
    final demoSalt = HashUtils.generateSalt();
    final demoHash = HashUtils.hashPassword('Password123!', demoSalt);

    await Database.users.insertOne({
      '_id': demoUserId,
      'email': 'vornsoroth@gmail.com',
      'name': 'soroth',
      'passwordHash': demoHash,
      'salt': demoSalt,
      'phone': '+1 (555) 019-2834',
      'dob': '1995-04-12',
      'avatar':
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
      'provider': 'local',
      'referralCode': 'SOROTH2026',
      'loyaltyPoints': 250,
      'loyaltyTier': 'Gold',
      'createdAt': now,
      'updatedAt': now,
    });

    final demoUserIdStr = demoUserId.oid;

    // Notification settings for demo user
    await Database.notificationSettings.insertOne({
      '_id': ObjectId(),
      'userId': demoUserIdStr,
      'orderUpdates': true,
      'promotions': true,
      'priceAlerts': true,
      'inAppNotifications': true,
      'emailNotifications': true,
      'smsNotifications': false,
      'updatedAt': now,
    });

    final categoriesData = [
      {
        '_id': ObjectId(),
        'id': 'footwear',
        'name': 'Footwear',
        'slug': 'footwear',
        'icon': 'shoe-sneaker',
        'image':
            'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=600&q=80',
      },
      {
        '_id': ObjectId(),
        'id': 'electronics',
        'name': 'Electronics',
        'slug': 'electronics',
        'icon': 'headphones',
        'image':
            'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=600&q=80',
      },
      {
        '_id': ObjectId(),
        'id': 'fashion',
        'name': 'Fashion & Apparel',
        'slug': 'fashion',
        'icon': 'tshirt-crew',
        'image':
            'https://images.unsplash.com/photo-1489987707025-afc232f7ea0f?auto=format&fit=crop&w=600&q=80',
      },
      {
        '_id': ObjectId(),
        'id': 'sports',
        'name': 'Sports & Outdoors',
        'slug': 'sports',
        'icon': 'basketball',
        'image':
            'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&w=600&q=80',
      },
      {
        '_id': ObjectId(),
        'id': 'home-living',
        'name': 'Home & Living',
        'slug': 'home-living',
        'icon': 'home',
        'image':
            'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=600&q=80',
      },
    ];
    await Database.categories.insertMany(categoriesData);

    final brandsData = [
      {
        '_id': ObjectId(),
        'name': 'Nike',
        'slug': 'nike',
        'logo':
            'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=200&q=80',
        'description': 'Just Do It. Premium athletic footwear and apparel.',
        'banner':
            'https://images.unsplash.com/photo-1552346154-21d32810aba3?auto=format&fit=crop&w=1200&q=80',
      },
      {
        '_id': ObjectId(),
        'name': 'Apple',
        'slug': 'apple',
        'logo':
            'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?auto=format&fit=crop&w=200&q=80',
        'description':
            'Think Different. State-of-the-art smartphones, wearables, and electronics.',
        'banner':
            'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=1200&q=80',
      },
      {
        '_id': ObjectId(),
        'name': 'Sony',
        'slug': 'sony',
        'logo':
            'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=200&q=80',
        'description':
            'Leading audio technology, headphones, and gaming gear.',
        'banner':
            'https://images.unsplash.com/photo-1546435770-a3e426bf472b?auto=format&fit=crop&w=1200&q=80',
      },
      {
        '_id': ObjectId(),
        'name': 'Adidas',
        'slug': 'adidas',
        'logo':
            'https://images.unsplash.com/photo-1518002171953-a080ee817e1f?auto=format&fit=crop&w=200&q=80',
        'description':
            'Impossible is Nothing. Iconic sportswear and footwear.',
        'banner':
            'https://images.unsplash.com/photo-1556906781-9a412961c28c?auto=format&fit=crop&w=1200&q=80',
      },
      {
        '_id': ObjectId(),
        'name': 'Zara',
        'slug': 'zara',
        'logo':
            'https://images.unsplash.com/photo-1489987707025-afc232f7ea0f?auto=format&fit=crop&w=200&q=80',
        'description': 'Modern and contemporary high-street fashion.',
        'banner':
            'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=1200&q=80',
      },
    ];
    await Database.brands.insertMany(brandsData);

    final p1Id = ObjectId();
    final p2Id = ObjectId();
    final p3Id = ObjectId();
    final p4Id = ObjectId();
    final p5Id = ObjectId();
    final p6Id = ObjectId();

    final productsData = [
      {
        '_id': p1Id,
        'name': 'Nike Air Max 270 React',
        'slug': 'nike-air-max-270-react',
        'description':
            'The Nike Air Max 270 React merges artistic style with continuous cushioning for all-day comfort.',
        'price': 0.01,
        'compareAtPrice': 0.02,
        'categoryId': 'footwear',
        'category': 'Footwear',
        'brand': 'Nike',
        'brandSlug': 'nike',
        'images': [
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1608231387042-66d1773070a5?auto=format&fit=crop&w=800&q=80',
        ],
        'thumbnail':
            'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=400&q=80',
        'stock': 45,
        'isNew': true,
        'rating': 4.8,
        'reviewCount': 24,
        'colors': ['Crimson Red', 'Triple Black', 'Pure White'],
        'sizes': ['US 8', 'US 9', 'US 10', 'US 11'],
        'tags': ['sneakers', 'running', 'lifestyle', 'air max'],
        'flashSale': {
          'active': true,
          'discountPercentage': 25,
          'salePrice': 0.01,
          'endTime': now.add(const Duration(days: 3)).toIso8601String(),
        },
        'createdAt': now.subtract(const Duration(days: 2)),
        'updatedAt': now,
      },
      {
        '_id': p2Id,
        'name': 'Sony WH-1000XM5 Wireless Headphones',
        'slug': 'sony-wh-1000xm5-wireless-headphones',
        'description':
            'Industry-leading noise cancellation with 30-hour battery life and crystal-clear hands-free calling.',
        'price': 0.02,
        'compareAtPrice': 0.03,
        'categoryId': 'electronics',
        'category': 'Electronics',
        'brand': 'Sony',
        'brandSlug': 'sony',
        'images': [
          'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1583394838336-acd977736f90?auto=format&fit=crop&w=800&q=80',
        ],
        'thumbnail':
            'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=400&q=80',
        'stock': 30,
        'isNew': true,
        'rating': 4.9,
        'reviewCount': 58,
        'colors': ['Midnight Black', 'Silver Grey'],
        'sizes': ['One Size'],
        'tags': ['audio', 'noise cancelling', 'bluetooth', 'sony'],
        'flashSale': {
          'active': true,
          'discountPercentage': 15,
          'salePrice': 0.02,
          'endTime': now.add(const Duration(days: 2)).toIso8601String(),
        },
        'createdAt': now.subtract(const Duration(days: 1)),
        'updatedAt': now,
      },
      {
        '_id': p3Id,
        'name': 'Apple Watch Series 9 GPS 45mm',
        'slug': 'apple-watch-series-9-gps-45mm',
        'description':
            'Smarter, brighter, mightier. Advanced health tracking and Double Tap gesture.',
        'price': 0.01,
        'compareAtPrice': 0.02,
        'categoryId': 'electronics',
        'category': 'Electronics',
        'brand': 'Apple',
        'brandSlug': 'apple',
        'images': [
          'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?auto=format&fit=crop&w=800&q=80',
        ],
        'thumbnail':
            'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?auto=format&fit=crop&w=400&q=80',
        'stock': 25,
        'isNew': true,
        'rating': 4.7,
        'reviewCount': 35,
        'colors': ['Midnight', 'Starlight', 'Product RED'],
        'sizes': ['41mm', '45mm'],
        'tags': ['smartwatch', 'apple', 'fitness', 'wearable'],
        'createdAt': now.subtract(const Duration(days: 3)),
        'updatedAt': now,
      },
      {
        '_id': p4Id,
        'name': 'Adidas Ultraboost Light Running Shoes',
        'slug': 'adidas-ultraboost-light-running-shoes',
        'description':
            'Experience epic energy with our lightest Ultraboost ever made.',
        'price': 0.02,
        'compareAtPrice': 0.03,
        'categoryId': 'footwear',
        'category': 'Footwear',
        'brand': 'Adidas',
        'brandSlug': 'adidas',
        'images': [
          'https://images.unsplash.com/photo-1587563871167-1ee9c731aefb?auto=format&fit=crop&w=800&q=80',
        ],
        'thumbnail':
            'https://images.unsplash.com/photo-1587563871167-1ee9c731aefb?auto=format&fit=crop&w=400&q=80',
        'stock': 50,
        'isNew': false,
        'rating': 4.6,
        'reviewCount': 19,
        'colors': ['Cloud White', 'Core Black', 'Solar Red'],
        'sizes': ['US 8', 'US 8.5', 'US 9', 'US 10', 'US 11'],
        'tags': ['adidas', 'ultraboost', 'running', 'comfort'],
        'createdAt': now.subtract(const Duration(days: 10)),
        'updatedAt': now,
      },
      {
        '_id': p5Id,
        'name': 'Zara Oversized Wool Blend Coat',
        'slug': 'zara-oversized-wool-blend-coat',
        'description':
            'Long sleeve coat made of a wool blend with lapel collar and front flap pockets.',
        'price': 0.01,
        'compareAtPrice': 0.02,
        'categoryId': 'fashion',
        'category': 'Fashion & Apparel',
        'brand': 'Zara',
        'brandSlug': 'zara',
        'images': [
          'https://images.unsplash.com/photo-1539533018447-63fcce2678e3?auto=format&fit=crop&w=800&q=80',
        ],
        'thumbnail':
            'https://images.unsplash.com/photo-1539533018447-63fcce2678e3?auto=format&fit=crop&w=400&q=80',
        'stock': 20,
        'isNew': true,
        'rating': 4.5,
        'reviewCount': 12,
        'colors': ['Camel', 'Anthracite Grey', 'Black'],
        'sizes': ['S', 'M', 'L'],
        'tags': ['zara', 'coat', 'winter', 'wool'],
        'createdAt': now.subtract(const Duration(days: 4)),
        'updatedAt': now,
      },
      {
        '_id': p6Id,
        'name': 'Nike Club Fleece Pullover Hoodie',
        'slug': 'nike-club-fleece-pullover-hoodie',
        'description':
            'A wardrobe staple, the Nike Sportswear Club Fleece Hoodie combines classic style with soft brushed fleece.',
        'price': 0.02,
        'compareAtPrice': 0.03,
        'categoryId': 'fashion',
        'category': 'Fashion & Apparel',
        'brand': 'Nike',
        'brandSlug': 'nike',
        'images': [
          'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?auto=format&fit=crop&w=800&q=80',
        ],
        'thumbnail':
            'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?auto=format&fit=crop&w=400&q=80',
        'stock': 80,
        'isNew': false,
        'rating': 4.8,
        'reviewCount': 42,
        'colors': ['Dark Grey Heather', 'Black', 'Club Navy'],
        'sizes': ['S', 'M', 'L', 'XL', 'XXL'],
        'tags': ['nike', 'hoodie', 'fleece', 'streetwear'],
        'flashSale': {
          'active': true,
          'discountPercentage': 30,
          'salePrice': 0.02,
          'endTime': now.add(const Duration(days: 4)).toIso8601String(),
        },
        'createdAt': now.subtract(const Duration(days: 15)),
        'updatedAt': now,
      },
    ];
    await Database.products.insertMany(productsData);

    final reviewsData = [
      {
        '_id': ObjectId(),
        'productId': p1Id.oid,
        'userId': demoUserIdStr,
        'userName': 'soroth',
        'userAvatar':
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=100&q=80',
        'rating': 5,
        'text': 'Super comfortable for everyday wear! Looks amazing in person.',
        'photos': [
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=600&q=80',
        ],
        'createdAt': now.subtract(const Duration(days: 1)),
      },
      {
        '_id': ObjectId(),
        'productId': p1Id.oid,
        'userId': ObjectId().oid,
        'userName': 'Jessica Miller',
        'userAvatar':
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=100&q=80',
        'rating': 5,
        'text': 'Fits true to size. The cushioning feels like walking on clouds.',
        'photos': <String>[],
        'createdAt': now.subtract(const Duration(days: 3)),
      },
      {
        '_id': ObjectId(),
        'productId': p2Id.oid,
        'userId': demoUserIdStr,
        'userName': 'soroth',
        'userAvatar':
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=100&q=80',
        'rating': 5,
        'text':
            'Best noise cancellation on the market. Battery easily lasts the whole work week.',
        'photos': <String>[],
        'createdAt': now.subtract(const Duration(hours: 12)),
      },
    ];
    await Database.reviews.insertMany(reviewsData);

    await Database.addresses.insertOne({
      '_id': ObjectId(),
      'userId': demoUserIdStr,
      'name': 'soroth',
      'phone': '+1 (555) 019-2834',
      'street': '742 Evergreen Terrace',
      'city': 'Springfield',
      'state': 'IL',
      'postalCode': '62704',
      'country': 'United States',
      'label': 'Home',
      'isDefault': true,
      'createdAt': now,
      'updatedAt': now,
    });

    await Database.paymentMethods.insertOne({
      '_id': ObjectId(),
      'userId': demoUserIdStr,
      'type': 'card',
      'cardHolder': 'SOROTH',
      'last4': '4242',
      'brand': 'Visa',
      'expiryMonth': 8,
      'expiryYear': 2028,
      'token': 'tok_seed_demo_visa_4242',
      'isDefault': true,
      'createdAt': now,
      'updatedAt': now,
    });

    final vouchersData = [
      {
        '_id': ObjectId(),
        'code': 'WELCOME10',
        'description': '10% discount on orders over \$50',
        'discountType': 'percentage',
        'discountValue': 10.0,
        'minSpend': 50.0,
        'maxDiscount': 25.0,
        'expiresAt': now.add(const Duration(days: 90)).toIso8601String(),
        'isActive': true,
        'usedByUsers': <String>[],
      },
      {
        '_id': ObjectId(),
        'code': 'SAVE20',
        'description': '20% off entire order (min spend \$100)',
        'discountType': 'percentage',
        'discountValue': 20.0,
        'minSpend': 100.0,
        'maxDiscount': 50.0,
        'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
        'isActive': true,
        'usedByUsers': <String>[],
      },
      {
        '_id': ObjectId(),
        'code': 'FLASHSALE50',
        'description': '\$50 fixed discount on orders over \$200',
        'discountType': 'fixed',
        'discountValue': 50.0,
        'minSpend': 200.0,
        'expiresAt': now.add(const Duration(days: 7)).toIso8601String(),
        'isActive': true,
        'usedByUsers': <String>[],
      },
    ];
    await Database.vouchers.insertMany(vouchersData);

    final faqsData = [
      {
        '_id': ObjectId(),
        'category': 'Orders & Shipping',
        'question': 'How long will delivery take?',
        'answer':
            'Standard shipping takes 3-5 business days. Express shipping delivers within 1-2 business days.',
      },
      {
        '_id': ObjectId(),
        'category': 'Orders & Shipping',
        'question': 'Can I track my order live?',
        'answer':
            'Yes! You can view step-by-step live tracking directly from your Orders tab.',
      },
      {
        '_id': ObjectId(),
        'category': 'Returns & Refunds',
        'question': 'What is your return policy?',
        'answer':
            'You can return any unworn, unwashed items with tags within 30 days of delivery.',
      },
      {
        '_id': ObjectId(),
        'category': 'Payment & Vouchers',
        'question': 'How do I redeem loyalty points?',
        'answer':
            'Every 100 loyalty points equals \$5 discount credit. You can apply points directly on checkout.',
      },
    ];
    await Database.faqs.insertMany(faqsData);

    final stylePosts = [
      {
        '_id': ObjectId(),
        'title': 'Minimalist Streetwear Essentials',
        'description':
            'Pairing the iconic Nike Air Max 270 with relaxed fit fleece hoodie for a clean weekend look.',
        'imageUrl':
            'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=800&q=80',
        'author': {
          'name': 'Marcus Vance',
          'avatar':
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80',
          'role': 'Style Curator',
        },
        'taggedProductIds': [p1Id.oid, p6Id.oid],
        'likesCount': 142,
        'likedByUserIds': [demoUserIdStr],
        'createdAt': now.subtract(const Duration(days: 1)),
      },
      {
        '_id': ObjectId(),
        'title': 'Studio Workspace Audio Aesthetics',
        'description':
            'Elevate your focus with the Sony WH-1000XM5. Superior sound meets all-day comfort.',
        'imageUrl':
            'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=800&q=80',
        'author': {
          'name': 'Elena Rostova',
          'avatar':
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
          'role': 'Tech & Audio Stylist',
        },
        'taggedProductIds': [p2Id.oid],
        'likesCount': 89,
        'likedByUserIds': <String>[],
        'createdAt': now.subtract(const Duration(days: 3)),
      },
    ];
    await Database.styleFeed.insertMany(stylePosts);

    await Database.notifications.insertOne({
      '_id': ObjectId(),
      'userId': demoUserIdStr,
      'title': 'Flash Sale is Live!',
      'body':
          'Get up to 30% off selected sneakers and audio accessories today.',
      'type': 'promo',
      'isRead': false,
      'createdAt': now.subtract(const Duration(hours: 5)),
    });
  }
}
