import 'package:flutter_test/flutter_test.dart';

import 'package:jj_clover_sms/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('JJ Clover SMS Dispatch'), findsOneWidget);
  });
}
