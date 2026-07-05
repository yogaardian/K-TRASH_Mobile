import 'package:flutter_test/flutter_test.dart';
import 'package:user/features/dashboard/providers/dashboard_provider.dart';

void main() {
  group('DashboardProvider', () {
    test('exposes formatted balance helpers and sample price data', () {
      final provider = DashboardProvider();

      expect(provider.getFormattedAvailableBalance(), 'Rp 0');
      expect(provider.getFormattedHoldBalance(), 'Rp 0');
      expect(provider.hargaSampah, isEmpty);
    });
  });
}
