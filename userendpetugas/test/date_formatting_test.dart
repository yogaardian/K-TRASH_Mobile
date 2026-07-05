import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:user/main.dart';

void main() {
  test('initializes Indonesian locale before formatting dates', () async {
    await initializeAppLocalization();

    final formatted = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(
      DateTime(2024, 1, 2, 3, 4),
    );

    expect(formatted, contains('02'));
    expect(formatted, contains('Jan'));
  });
}
