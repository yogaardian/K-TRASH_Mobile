import 'package:flutter/material.dart';
import '../constants/route_constants.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/register_page.dart';
import '../features/auth/pages/otp_page.dart';
import '../features/auth/pages/splash_page.dart';
import '../features/dashboard/pages/user_dashboard_page.dart';
import '../features/dashboard/pages/driver_dashboard_page.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/history/pages/history_page.dart';
import '../features/orders/pages/pickup_page.dart';
import '../features/orders/pages/select_waste_page.dart';
import '../features/orders/pages/find_driver_page.dart';
import '../features/orders/pages/result_page.dart';
import '../features/tracking/pages/tracking_page.dart';
import '../features/tracking/pages/driver_tracking_page.dart';
import '../features/marketplace/pages/marketplace_page.dart';
import '../features/dashboard/pages/price_list_page.dart';
// Driver routes
import '../features/driver/pages/driver_order_detail_page.dart';
import '../features/driver/pages/driver_journey_page.dart';
import '../features/driver/pages/customer_search_page.dart';
import '../features/driver/pages/weigh_waste_page.dart';
import '../features/driver/pages/driver_profile_page.dart';
import '../features/driver/pages/driver_history_page.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Auth Routes
      case RouteConstants.splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());

      case RouteConstants.login:
        return MaterialPageRoute(builder: (_) => LoginPage());

      case RouteConstants.register:
        return MaterialPageRoute(builder: (_) => RegisterPage());

      case RouteConstants.otp:
        final email = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => OtpPage(email: email ?? ''),
        );

      // User Routes
      case RouteConstants.userDashboard:
      case '/dashboard':
        return MaterialPageRoute(builder: (_) => UserDashboardPage());

      case RouteConstants.userProfile:
        return MaterialPageRoute(builder: (_) => ProfilePage());

      case RouteConstants.userHistory:
        return MaterialPageRoute(builder: (_) => HistoryPage());

      case RouteConstants.userSaldo:
        // TODO: Implement Saldo page
        return MaterialPageRoute(builder: (_) => UserDashboardPage());

      case RouteConstants.userHarga:
        return MaterialPageRoute(builder: (_) => const PriceListPage());

      // Order Routes
      case RouteConstants.pickupPage:
      case '/pickup':
        return MaterialPageRoute(builder: (_) => PickupPage());

      case RouteConstants.selectWaste:
      case '/select-waste':
        final orderId = settings.arguments as int?;
        return MaterialPageRoute(
          builder: (_) => SelectWastePage(orderId: orderId),
        );

      case RouteConstants.findDriver:
      case '/find-driver':
        final orderId = settings.arguments as int?;
        return MaterialPageRoute(
          builder: (_) => FindDriverPage(orderId: orderId),
        );

      case RouteConstants.orderResult:
      case '/result':
        final orderId = settings.arguments as int?;
        return MaterialPageRoute(
          builder: (_) => ResultPage(orderId: orderId),
        );

      // Tracking Routes
      case RouteConstants.trackingPage:
        final orderId = settings.arguments as int?;
        return MaterialPageRoute(
          builder: (_) => TrackingPage(orderId: orderId),
        );

      case RouteConstants.driverTracking:
        final orderId = settings.arguments as int?;
        return MaterialPageRoute(
          builder: (_) => DriverTrackingPage(orderId: orderId),
        );

      // Marketplace Routes
      case RouteConstants.marketplace:
        return MaterialPageRoute(builder: (_) => MarketplacePage());

      // Driver Routes
      case RouteConstants.driverDashboard:
      case '/driver-dashboard':
        return MaterialPageRoute(builder: (_) => DriverDashboardPage());

      case '/driver-detail':
      case '/order-detail':
        final order = settings.arguments as dynamic;
        final driverId = settings.arguments is Map
            ? (settings.arguments as Map)['driverId'] as int? ?? 1
            : 1;
        return MaterialPageRoute(
          builder: (_) => DriverOrderDetailPage(
            order: order,
            driverId: driverId,
          ),
        );

      case '/driver-journey':
        final args = settings.arguments as Map?;
        final driverId = args?['driverId'] as int? ?? 1;
        final orderId = args?['orderId'] as int? ?? 1;
        return MaterialPageRoute(
          builder: (_) => DriverJourneyPage(
            driverId: driverId,
            orderId: orderId,
          ),
        );

      case '/customer-search':
        final args = settings.arguments as Map?;
        final driverId = args?['driverId'] as int? ?? 1;
        final orderId = args?['orderId'] as int? ?? 1;
        return MaterialPageRoute(
          builder: (_) => CustomerSearchPage(
            driverId: driverId,
            orderId: orderId,
          ),
        );

      case '/weigh-waste':
        final args = settings.arguments as Map?;
        final user = args?['user'] as Map<String, String>? ?? {};
        final driverId = args?['driverId'] as int? ?? 1;
        final orderId = args?['orderId'] as int? ?? 1;
        return MaterialPageRoute(
          builder: (_) => WeighWastePage(
            user: user,
            driverId: driverId,
            orderId: orderId,
          ),
        );

      case RouteConstants.driverProfile:
      case '/driver-profile':
        return MaterialPageRoute(builder: (_) => const DriverProfilePage());

      case '/driver-history':
        return MaterialPageRoute(builder: (_) => const DriverHistoryPage());

      // Default route
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route ${settings.name} not found'),
            ),
          ),
        );
    }
  }
}
