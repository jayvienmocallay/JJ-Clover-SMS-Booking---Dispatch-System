// Task 009 — Updated widget test for PermissionGate initial state
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/main.dart';

void main() {
  testWidgets('App loads and shows permission request screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    // The PermissionGate widget shows "Requesting permissions..." while checking
    expect(find.text('Requesting permissions...'), findsOneWidget);
  });
}
