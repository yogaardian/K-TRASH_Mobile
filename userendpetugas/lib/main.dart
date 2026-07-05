import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'core/app_router.dart';
import 'core/auth_wrapper.dart';
import 'package:user/features/auth/providers/auth_provider.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/orders/providers/order_provider.dart';
import 'features/driver/providers/driver_provider.dart';
import 'utils/secure_storage_helper.dart';

Future<void> initializeAppLocalization() async {
  await initializeDateFormatting('id_ID', null);
  await initializeDateFormatting('en_US', null);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppLocalization();

  if (kDebugMode) {
    await SecureStorageHelper.clearAll();
  }

  runApp(const KTrashApp());
}

class KTrashApp extends StatelessWidget {
  const KTrashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(),
        ),
        ChangeNotifierProvider<OrderProvider>(
          create: (_) => OrderProvider(),
        ),
        ChangeNotifierProvider<DriverProvider>(
          create: (_) => DriverProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'K-TRASH',
        theme: ThemeData(primarySwatch: Colors.green),
        home: const AuthWrapper(),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
