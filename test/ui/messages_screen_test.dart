import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/repositories/customer_repository.dart';
import 'package:jj_clover_sms/data/repositories/sms_message_repository.dart';
import 'package:jj_clover_sms/ui/screens/messages_screen.dart';
import 'package:jj_clover_sms/ui/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('messages screen shows retry state and recovers on retry', (
    tester,
  ) async {
    final smsRepo = _FlakySmsMessageRepository([
      {
        'phone_number': '09181112222',
        'message': 'Latest conversation preview',
        'direction': 'incoming',
        'sent_at': DateTime(2026, 5, 19, 9).toIso8601String(),
      },
    ]);
    final customerRepo = _FakeCustomerRepository([
      {'contact_number': '09181112222', 'name': 'Retry Customer'},
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SmsMessageRepository>.value(value: smsRepo),
          Provider<CustomerRepository>.value(value: customerRepo),
        ],
        child: MaterialApp(theme: _testTheme, home: const MessagesScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Messages could not load'), findsOneWidget);
    expect(
      find.text('Unable to load messages. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Messages could not load'), findsNothing);
    expect(find.text('Retry Customer'), findsOneWidget);
    expect(find.text('Latest conversation preview'), findsOneWidget);
  });
}

class _FlakySmsMessageRepository extends SmsMessageRepository {
  _FlakySmsMessageRepository(this._messages);

  final List<Map<String, dynamic>> _messages;
  int _loadAttempts = 0;

  @override
  Future<List<Map<String, dynamic>>> getAllSmsMessages({int? limit}) async {
    _loadAttempts += 1;
    if (_loadAttempts == 1) {
      throw StateError('temporary failure');
    }
    return _messages;
  }
}

class _FakeCustomerRepository extends CustomerRepository {
  _FakeCustomerRepository(this._customers);

  final List<Map<String, dynamic>> _customers;

  @override
  Future<List<Map<String, dynamic>>> getCustomers() async => _customers;
}

final ThemeData _testTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    surface: AppColors.card,
    primary: AppColors.primary,
    onPrimary: AppColors.primaryForeground,
    onSurface: AppColors.foreground,
    error: AppColors.statusMaintenance,
  ),
  extensions: const [
    AppPalette(
      background: AppColors.background,
      card: AppColors.card,
      foreground: AppColors.foreground,
      primary: AppColors.primary,
      primaryForeground: AppColors.primaryForeground,
      muted: AppColors.muted,
      mutedForeground: AppColors.mutedForeground,
      border: AppColors.border,
      statusOperating: AppColors.statusOperating,
      statusOperatingLight: AppColors.statusOperatingLight,
      statusAway: AppColors.statusAway,
      statusAwayLight: AppColors.statusAwayLight,
      statusBusy: AppColors.statusBusy,
      statusBusyLight: AppColors.statusBusyLight,
      statusMaintenance: AppColors.statusMaintenance,
      statusMaintenanceLight: AppColors.statusMaintenanceLight,
      primaryLight: AppColors.primaryLight,
    ),
  ],
);
