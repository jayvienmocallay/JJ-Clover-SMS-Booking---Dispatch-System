import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/repositories/barangay_repository.dart';
import 'package:jj_clover_sms/data/repositories/customer_repository.dart';
import 'package:jj_clover_sms/data/repositories/order_repository.dart';
import 'package:jj_clover_sms/ui/theme/app_theme.dart';
import 'package:jj_clover_sms/ui/widgets/add_order_form.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'add order form shows barangay retry state and recovers for save-customer flow',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<CustomerRepository>.value(
              value: _FakeCustomerRepository(),
            ),
            Provider<OrderRepository>.value(value: _FakeOrderRepository()),
            Provider<BarangayRepository>.value(
              value: _FlakyBarangayRepository([
                {'id': 1, 'name': 'Poblacion', 'delivery_zone': 'A'},
              ]),
            ),
          ],
          child: MaterialApp(
            theme: _testTheme,
            home: const Scaffold(body: AddOrderForm()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Save this customer for future orders'));
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to load barangays. Please try again.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to load barangays. Please try again.'),
        findsNothing,
      );
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(find.text('Select barangay'), findsOneWidget);
    },
  );
}

class _FakeCustomerRepository extends CustomerRepository {
  @override
  Future<Map<String, dynamic>?> getCustomerWithBarangayByPhone(
    String phoneNumber,
  ) async {
    return null;
  }
}

class _FakeOrderRepository extends OrderRepository {}

class _FlakyBarangayRepository extends BarangayRepository {
  _FlakyBarangayRepository(this._barangays);

  final List<Map<String, dynamic>> _barangays;
  int _loadAttempts = 0;

  @override
  Future<List<Map<String, dynamic>>> getBarangays() async {
    _loadAttempts += 1;
    if (_loadAttempts == 1) {
      throw StateError('temporary failure');
    }
    return _barangays;
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
