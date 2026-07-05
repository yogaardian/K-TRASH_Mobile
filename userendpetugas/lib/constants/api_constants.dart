import 'package:flutter/foundation.dart';

class ApiConstants {
  // Environment URLs
  static const String productionBaseUrl =
      'https://api-ktrashuns.tifpsdku.com';
  static const String developmentBaseUrl = 'http://localhost:5000';
  static const String localBaseUrl = 'http://10.0.2.2:5000';
  static const String backendUrlOverride = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  // Select based on runtime platform: web uses localhost.
  // On Android emulator, use 10.0.2.2 to reach the host machine.
  // Use dart-define to override: flutter run --dart-define=FLUTTER_ENVIRONMENT=production
  // For physical devices or custom hosts, provide BACKEND_URL.
  static String get baseUrl {
    const env = String.fromEnvironment(
      'FLUTTER_ENVIRONMENT',
      defaultValue: 'development',
    );

    if (kIsWeb) {
      return developmentBaseUrl;
    }

    if (backendUrlOverride.isNotEmpty) {
      return backendUrlOverride;
    }

    if (env == 'production') {
      return productionBaseUrl;
    }

    // Default to the emulator local URL for native mobile builds.
    return localBaseUrl;
  }

  // Socket.IO configuration
  static String get socketUrl => baseUrl;

  // Auth Endpoints
  static const String loginEndpoint = '/api/auth/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String registerVerifyEndpoint = '/api/auth/register/verify';
  static const String registerResendOtpEndpoint = '/api/auth/register/resend';
  static const String validateTokenEndpoint = '/api/auth/validate-token';
  static const String googleLoginEndpoint = '/api/auth/google-login';

  // User Endpoints
  static const String getUserBalanceEndpoint = '/user/balance';
  static const String getUserProfileEndpoint = '/user/profile';
  static const String updateUserEndpoint = '/users';

  // Order Endpoints
  static const String createOrderEndpoint = '/orders';
  static const String getOrderDetailEndpoint = '/orders';
  static const String getUserOrdersEndpoint = '/orders/user';
  static const String getDriverOrdersEndpoint = '/orders/driver';
  static const String getPendingOrdersEndpoint = '/orders/pending';
  static const String acceptOrderEndpoint = '/orders/accept';
  static const String rejectOrderEndpoint = '/orders';
  static const String updateOrderStatusEndpoint = '/orders/status';
  static const String getTrackingEndpoint = '/tracking';

  // Driver Location Endpoints
  static const String sendDriverLocationEndpoint = '/driver/location';

  // Waste Endpoints
  static const String getWasteCategoriesEndpoint = '/api/kategori-sampah';
  static const String getWasteTypesEndpoint = '/api/jenis-sampah';
  static const String getWasteTypesByCategoryEndpoint =
      '/api/jenis-sampah/kategori';

  // Marketplace Endpoints
  static const String getMarketplaceProductsEndpoint = '/marketplace/products';
  static const String createMarketplaceOrderEndpoint = '/marketplace/products';

  // Wallet Endpoints
  static const String getWalletEndpoint = '/wallet';

  // HTTP Headers
  static const String contentTypeHeader = 'Content-Type';
  static const String applicationJsonHeader = 'application/json';
  static const String authorizationHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer';

  // Timeouts (in seconds)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;
  static const int sendTimeout = 30;
}
