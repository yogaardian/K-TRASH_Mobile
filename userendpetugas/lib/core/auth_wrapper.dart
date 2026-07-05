import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/route_constants.dart';
import '../shared/models/user_model.dart';
import 'package:user/features/auth/providers/auth_provider.dart';
import '../features/auth/pages/splash_page.dart';
import '../features/auth/pages/login_page.dart';
import '../features/dashboard/pages/user_dashboard_page.dart';
import '../features/dashboard/pages/driver_dashboard_page.dart';

String getInitialRouteByRole(UserModel user) {
  final role = user.role.toLowerCase();

  switch (role) {
    case 'user':
      return RouteConstants.userDashboard;
    case 'driver':
    case 'petugas':
      return RouteConstants.driverDashboard;
    default:
      return RouteConstants.login;
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    switch (authProvider.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const SplashPage();

      case AuthStatus.authenticated:
        final user = authProvider.user;
        if (user == null) {
          return const LoginPage();
        }

        final route = getInitialRouteByRole(user);
        if (route == RouteConstants.userDashboard) {
          return const UserDashboardPage();
        }
        if (route == RouteConstants.driverDashboard) {
          return const DriverDashboardPage();
        }
        return const LoginPage();

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginPage();
    }
  }
}
