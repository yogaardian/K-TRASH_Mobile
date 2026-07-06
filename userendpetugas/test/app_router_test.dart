import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user/core/app_router.dart';
import 'package:user/features/tracking/pages/tracking_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('result route opens tracking page directly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold).first);

    final route = AppRouter.generateRoute(
      const RouteSettings(name: '/result', arguments: 42),
    );

    final materialRoute = route as MaterialPageRoute;
    final page = materialRoute.builder(context);

    expect(page, isA<TrackingPage>());
  });
}
