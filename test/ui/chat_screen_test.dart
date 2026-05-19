import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/repositories/sms_message_repository.dart';
import 'package:jj_clover_sms/ui/screens/chat_screen.dart';
import 'package:jj_clover_sms/ui/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'chat groups malformed sent_at values under Unknown date and expands one row at a time',
    (tester) async {
      final smsRepo = _FakeSmsMessageRepository([
        {
          'id': 1,
          'phone_number': '09181112222',
          'message': 'First malformed message',
          'direction': 'incoming',
          'status': 'received',
          'sent_at': '',
        },
        {
          'id': 2,
          'phone_number': '09181112222',
          'message': 'Second malformed message',
          'direction': 'outgoing',
          'status': 'sent',
          'sent_at': '',
        },
      ]);

      await tester.pumpWidget(
        Provider<SmsMessageRepository>.value(
          value: smsRepo,
          child: MaterialApp(
            theme: _testTheme,
            home: const ChatScreen(
              phoneNumber: '09181112222',
              contactName: 'Test Customer',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unknown date'), findsOneWidget);
      expect(find.text('First malformed message'), findsOneWidget);
      expect(find.text('Second malformed message'), findsOneWidget);

      await tester.tap(find.text('First malformed message'));
      await tester.pumpAndSettle();

      expect(find.text('Unknown time'), findsOneWidget);
    },
  );
}

class _FakeSmsMessageRepository extends SmsMessageRepository {
  _FakeSmsMessageRepository(this._messages);

  final List<Map<String, dynamic>> _messages;

  @override
  Future<List<Map<String, dynamic>>> getSmsMessagesForPhone(
    String phoneNumber, {
    int? limit,
  }) async {
    return _messages
        .where((message) => message['phone_number'] == phoneNumber)
        .toList();
  }
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
