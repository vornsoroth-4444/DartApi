# E-Commerce API (Dart Frog & MongoDB)

A production-ready e-commerce REST API backend built with **Dart Frog** and **MongoDB**, organized cleanly into modular routes, controllers, services, and models.

---

## Architecture

```text
my_api/
├── routes/
│   ├── _middleware.dart                 # Global database connection & request logger
│   ├── health.dart                      # Health check endpoint (/health)
│   └── api/
│       └── v1/
│           ├── auth/                    # /api/v1/auth/*
│           ├── products/                # /api/v1/products/*
│           ├── categories/              # /api/v1/categories/*
│           ├── brands/                  # /api/v1/brands/*
│           ├── wishlist/                # /api/v1/wishlist/*
│           ├── cart/                    # /api/v1/cart/*
│           ├── checkout/                # /api/v1/checkout
│           ├── orders/                  # /api/v1/orders/*
│           ├── addresses/               # /api/v1/addresses/*
│           ├── payment-methods/         # /api/v1/payment-methods/*
│           ├── vouchers/                # /api/v1/vouchers/*
│           ├── loyalty/                 # /api/v1/loyalty/*
│           ├── referrals/               # /api/v1/referrals/*
│           ├── notifications/           # /api/v1/notifications/*
│           ├── faqs/                    # /api/v1/faqs/*
│           ├── support/                 # /api/v1/support/*
│           └── style-feed/              # /api/v1/style-feed/*
│
├── lib/
│   ├── controllers/                     # Request handling & HTTP response mapping
│   ├── services/                        # Business logic & data access
│   ├── models/                          # Data models
│   ├── database/                        # MongoDB connection & auto-seeding
│   └── utils/                           # JWT, hashing, & document helpers
│
└── test/
    ├── api_test.dart                    # Automated tests
    └── routes/index_test.dart
```

---

## Quick Start

### 1. Start Server
```bash
dart_frog dev
```
Base URL: `http://localhost:8080/api/v1`

### 2. Run Tests
```bash
dart test
```

### 3. Default Credentials
- **Email:** `vornsoroth@gmail.com`
- **Username / Name:** `soroth`
- **Password:** `Password123!`
- **Loyalty Points:** 250 Points (Gold Tier)
- **Referral Code:** `SOROTH2026`

---

## API Surface Specification

### 1. Authentication (`/api/v1/auth`)
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/auth/login` | Email + password login → returns JWT token & user |
| `POST` | `/api/v1/auth/signup` | Register new account with 100 welcome points |
| `POST` | `/api/v1/auth/logout` | Invalidate / blacklist session token |
| `POST` | `/api/v1/auth/forgot-password` | Generate reset OTP |
| `POST` | `/api/v1/auth/verify-otp` | Verify 6-digit OTP code & optionally set new password |
| `POST` | `/api/v1/auth/social` | OAuth login (`google`, `apple`, `facebook`) |
| `GET` | `/api/v1/auth/me` | Get current authenticated user profile |
| `PATCH` | `/api/v1/auth/me` | Update profile (name, phone, dob, avatar) |

### 2. Products & Catalog (`/api/v1/products`, `/api/v1/categories`, `/api/v1/brands`)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/products` | List products with `?category`, `?brand`, `?minPrice`, `?maxPrice`, `?sort`, `?page`, `?limit` |
| `GET` | `/api/v1/products/:id` | Single product detail by ID or slug |
| `GET` | `/api/v1/products/new-arrivals` | Products flagged `isNew: true` |
| `GET` | `/api/v1/products/flash-deals` | Active flash sale products |
| `GET` | `/api/v1/products/search?q=` | Full-text search across name, brand, category |
| `GET` | `/api/v1/categories` | All categories with dynamic live product counts |
| `GET` | `/api/v1/categories/:id/products` | Products filtered by category |
| `GET` | `/api/v1/brands/:slug` | Brand info + its product listings |

### 3. Reviews (`/api/v1/products/:id/reviews`)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/products/:id/reviews` | Paginated reviews for a product |
| `POST` | `/api/v1/products/:id/reviews` | Submit a review (`rating`, `text`, `photos`) & recalculate avg rating |
| `GET` | `/api/v1/products/:id/reviews/summary` | Rating breakdown (star counts 1-5, percentages, average) |

### 4. Wishlist (`/api/v1/wishlist`)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/wishlist` | Get saved wishlist items populated with product details |
| `POST` | `/api/v1/wishlist/:productId` | Add product to wishlist |
| `DELETE` | `/api/v1/wishlist/:productId` | Remove product from wishlist |

### 5. Cart (`/api/v1/cart`)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/cart` | Get cart contents with subtotal, shipping, and total |
| `POST` | `/api/v1/cart` | Add item (`productId`, `quantity`, `color`, `size`) with stock validation |
| `PATCH` | `/api/v1/cart/:itemId` | Update quantity or variant |
| `DELETE` | `/api/v1/cart/:itemId` | Remove item from cart |
| `DELETE` | `/api/v1/cart` | Clear entire cart |

### 6. Orders & Checkout (`/api/v1/checkout`, `/api/v1/orders`)
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/checkout` | Create order from cart (stock reduction, address, voucher, loyalty, payment) |
| `GET` | `/api/v1/orders` | List user's orders — supports `?status` filter |
| `GET` | `/api/v1/orders/:id` | Order detail with items and tracking snapshots |
| `GET` | `/api/v1/orders/:id/tracking` | Live tracking steps and carrier status |
| `POST` | `/api/v1/orders/:id/cancel` | Cancel order & restore inventory |
| `POST` | `/api/v1/orders/:id/return` | Initiate return request (`reason`, `items`, `notes`) |

### 7. Addresses (`/api/v1/addresses`)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/addresses` | List saved addresses |
| `POST` | `/api/v1/addresses` | Add new address |
| `PATCH` | `/api/v1/addresses/:id` | Edit an address |
| `DELETE` | `/api/v1/addresses/:id` | Delete an address |
| `PATCH` | `/api/v1/addresses/:id/default` | Set as default address |

### 8. Payment Methods & Bakong KHQR (`/api/v1/payment-methods`, `/api/v1/payments/bakong`)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/payment-methods` | List saved cards & wallets |
| `POST` | `/api/v1/payment-methods` | Add card (tokenized card data) |
| `DELETE` | `/api/v1/payment-methods/:id` | Remove a card |
| `PATCH` | `/api/v1/payment-methods/:id/default` | Set as default payment |
| `POST` | `/api/v1/payments/bakong/qr` | Generate standalone dynamic Bakong KHQR (`amount`, `currency`, `billNumber`) |
| `POST` | `/api/v1/payments/bakong/check-transaction` | Verify transaction status with NBC Bakong API by `orderNumber` or `md5` |

> **Bakong KHQR Checkout:** Pass `"paymentType": "khqr"` or `"bakong"` to `POST /api/v1/checkout`. The response returns the order with a `khqr` object containing `qrString`, `md5`, and official Bakong `shortLink` (`https://bakong-deeplink.nbc.gov.kh/...`).

### 9. Vouchers & Loyalty (`/api/v1/vouchers`, `/api/v1/loyalty`, `/api/v1/referrals`)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/vouchers` | List available vouchers |
| `POST` | `/api/v1/vouchers/apply` | Validate voucher code and compute discount on checkout subtotal |
| `GET` | `/api/v1/loyalty/points` | Current points balance + transaction history |
| `POST` | `/api/v1/loyalty/redeem` | Redeem points for discount credit |
| `GET` | `/api/v1/referrals` | Referral code + stats + list |
| `POST` | `/api/v1/referrals` | Submit a friend's referral code |

### 10. Notifications (`/api/v1/notifications`)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/notifications/settings` | Get notification preferences |
| `PATCH` | `/api/v1/notifications/settings` | Update preferences (orderUpdates, promotions, alerts) |
| `GET` | `/api/v1/notifications` | Notification inbox list |

### 11. Support (`/api/v1/faqs`, `/api/v1/support`)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/faqs` | All FAQ categories and questions |
| `GET` | `/api/v1/support/chat/history` | Chat message history |
| `POST` | `/api/v1/support/chat/send` | Send a message to customer support |

### 12. Style Feed (`/api/v1/style-feed`)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/style-feed` | Curated style posts with tagged products |
| `POST` | `/api/v1/style-feed/:id/like` | Like or toggle like on a style post |
