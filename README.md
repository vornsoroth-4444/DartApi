# My API

Backend API for mobile e-commerce application built with Dart Frog and MongoDB.

## Getting Started

### Prerequisites
- Dart SDK ^3.11.0
- Dart Frog CLI
- MongoDB running locally on port 27017

### Run Development Server
```bash
dart_frog dev
```
Server will be available at `http://localhost:8080/api/v1`.

### Run Tests
```bash
dart test
```

## Environment Variables
Create a `.env` file or export the following:
```bash
MONGODB_URI=mongodb://127.0.0.1:27017/my_api_db
JWT_SECRET=your_jwt_secret_here

# Bakong KHQR (Optional)
BAKONG_TOKEN=your_bakong_token
BAKONG_ACCOUNT_ID=lyhav_voeurn@bkrt
BAKONG_MERCHANT_NAME=LYHAV VOEURN
BAKONG_PHONE_NUMBER=067687806
```

## API Routes

### Auth (`/api/v1/auth`)
- `POST /api/v1/auth/login` - Login with email and password
- `POST /api/v1/auth/signup` - Register new account
- `POST /api/v1/auth/logout` - Logout
- `POST /api/v1/auth/forgot-password` - Request password reset OTP
- `POST /api/v1/auth/verify-otp` - Verify OTP code
- `POST /api/v1/auth/social` - Social login (google, apple, facebook)
- `GET /api/v1/auth/me` - Get current user profile
- `PATCH /api/v1/auth/me` - Update profile

### Products & Categories (`/api/v1/products`, `/api/v1/categories`, `/api/v1/brands`)
- `GET /api/v1/products` - List products (filters: category, brand, minPrice, maxPrice, sort, page, limit)
- `POST /api/v1/products` - Create new product
- `GET /api/v1/products/:id` - Product details
- `GET /api/v1/products/new-arrivals` - New arrivals
- `GET /api/v1/products/flash-deals` - Flash deals
- `GET /api/v1/products/search?q=` - Search products
- `GET /api/v1/categories` - List categories
- `GET /api/v1/categories/:id/products` - Products by category
- `GET /api/v1/brands/:slug` - Brand details

### Reviews (`/api/v1/products/:id/reviews`)
- `GET /api/v1/products/:id/reviews` - Product reviews
- `POST /api/v1/products/:id/reviews` - Submit review
- `GET /api/v1/products/:id/reviews/summary` - Review rating summary

### Wishlist (`/api/v1/wishlist`)
- `GET /api/v1/wishlist` - Get wishlist
- `POST /api/v1/wishlist/:productId` - Add to wishlist
- `DELETE /api/v1/wishlist/:productId` - Remove from wishlist

### Cart (`/api/v1/cart`)
- `GET /api/v1/cart` - Get user cart
- `POST /api/v1/cart` - Add item to cart
- `PATCH /api/v1/cart/:itemId` - Update cart item
- `DELETE /api/v1/cart/:itemId` - Remove cart item
- `DELETE /api/v1/cart` - Clear cart

### Orders & Checkout (`/api/v1/checkout`, `/api/v1/orders`)
- `POST /api/v1/checkout` - Checkout cart
- `GET /api/v1/orders` - List user orders
- `GET /api/v1/orders/:id` - Order details
- `GET /api/v1/orders/:id/tracking` - Tracking status
- `POST /api/v1/orders/:id/cancel` - Cancel order
- `POST /api/v1/orders/:id/return` - Request return

### Addresses (`/api/v1/addresses`)
- `GET /api/v1/addresses` - List addresses
- `POST /api/v1/addresses` - Add address
- `PATCH /api/v1/addresses/:id` - Update address
- `DELETE /api/v1/addresses/:id` - Delete address
- `PATCH /api/v1/addresses/:id/default` - Set default address

### Payments & Bakong KHQR (`/api/v1/payment-methods`, `/api/v1/payments/bakong`)
- `GET /api/v1/payment-methods` - List saved payment methods
- `POST /api/v1/payment-methods` - Add payment method
- `DELETE /api/v1/payment-methods/:id` - Delete payment method
- `PATCH /api/v1/payment-methods/:id/default` - Set default payment
- `POST /api/v1/payments/bakong/qr` - Generate KHQR payment string & deeplink
- `POST /api/v1/payments/bakong/check-transaction` - Check Bakong transaction status

### Vouchers & Loyalty (`/api/v1/vouchers`, `/api/v1/loyalty`, `/api/v1/referrals`)
- `GET /api/v1/vouchers` - List available vouchers
- `POST /api/v1/vouchers/apply` - Apply voucher code
- `GET /api/v1/loyalty/points` - Get loyalty points balance & history
- `POST /api/v1/loyalty/redeem` - Redeem loyalty points
- `GET /api/v1/referrals` - Referral stats & history

### Notifications & Support (`/api/v1/notifications`, `/api/v1/support`, `/api/v1/faqs`, `/api/v1/style-feed`)
- `GET /api/v1/notifications` - List notifications
- `GET /api/v1/notifications/settings` - Get notification preferences
- `PATCH /api/v1/notifications/settings` - Update notification preferences
- `GET /api/v1/faqs` - List FAQs
- `GET /api/v1/support/chat/history` - Chat history
- `POST /api/v1/support/chat/send` - Send chat message
- `GET /api/v1/style-feed` - Style feed posts
- `POST /api/v1/style-feed/:id/like` - Like/unlike style feed post
