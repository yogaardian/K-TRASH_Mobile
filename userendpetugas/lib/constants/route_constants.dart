class RouteConstants {
  // Root
  static const String root = '/';
  static const String splash = '/splash';

  // Auth Routes
  static const String intro = '/intro';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';

  // User Routes
  static const String userDashboard = '/user/dashboard';
  static const String userProfile = '/user/profile';
  static const String userHistory = '/user/history';
  static const String userSaldo = '/user/saldo';
  static const String userHarga = '/user/harga';

  // Order Routes
  static const String pickupPage = '/orders/pickup';
  static const String selectWaste = '/orders/select-waste';
  static const String findDriver = '/orders/find-driver';
  static const String orderResult = '/orders/result';

  // Tracking Routes
  static const String trackingPage = '/tracking/order';
  static const String driverTracking = '/tracking/driver';

  // Marketplace Routes
  static const String marketplace = '/marketplace';

  // Driver Routes
  static const String driverDashboard = '/driver/dashboard';
  static const String driverOrderDetail = '/driver/order/:orderId';
  static const String driverProfile = '/driver/profile';

  // Error Routes
  static const String error = '/error';
  static const String notFound = '/404';
}
