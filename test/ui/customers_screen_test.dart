import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/core/security/admin_auth_service.dart';
import 'package:jj_clover_sms/data/providers/customer_provider.dart';
import 'package:jj_clover_sms/data/repositories/audit_log_repository.dart';
import 'package:jj_clover_sms/data/repositories/barangay_repository.dart';
import 'package:jj_clover_sms/data/repositories/customer_repository.dart';
import 'package:jj_clover_sms/ui/screens/customers_screen.dart';
import 'package:jj_clover_sms/ui/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Always-unlocked stub — lets the admin gate pass without showing a dialog.
class _AlwaysUnlockedAdminAuthService implements AdminAuthService {
  @override
  bool get isUnlocked => true;
  @override
  Future<bool> isAdminConfigured() async => true;
  @override
  Future<bool> verifyPassword(String password) async => true;
  @override
  Future<void> unlockFor({Duration duration = const Duration(minutes: 5)}) async {}
  @override
  Future<void> lock() async {}
  @override
  Future<void> setPassword(String password) async {}
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
}

class _NoOpAuditLogRepository extends AuditLogRepository {
  @override
  Future<int> record({
    required String action,
    required String entityType,
    String? entityId,
    String? phoneNumber,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit customer sheet shows barangay retry state and recovers', (
    tester,
  ) async {
    final customerProvider = CustomerProvider(
      _FakeCustomerRepository([
        {
          'id': 1,
          'name': 'Retry Customer',
          'contact_number': '09181112222',
          'address': 'Sample Street',
          'barangay_id': 1,
          'barangay': 'Poblacion',
        },
      ]),
    );
    await customerProvider.loadCustomers();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CustomerProvider>.value(
            value: customerProvider,
          ),
          Provider<BarangayRepository>.value(
            value: _FlakyBarangayRepository([
              {'id': 1, 'name': 'Poblacion', 'delivery_zone': 'A'},
            ]),
          ),
          Provider<AdminAuthService>(
            create: (_) => _AlwaysUnlockedAdminAuthService(),
          ),
          Provider<AuditLogRepository>(
            create: (_) => _NoOpAuditLogRepository(),
          ),
        ],
        child: MaterialApp(
          theme: _testTheme,
          home: const Scaffold(body: CustomersScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('Edit customer (Admin required)'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit customer (Admin required)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to load barangays. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to load barangays. Please try again.'),
      findsNothing,
    );
    expect(find.text('Edit Customer'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DropdownButton<int?> && widget.value == 1,
      ),
      findsOneWidget,
    );
  });
}

class _FakeCustomerRepository extends CustomerRepository {
  _FakeCustomerRepository(this._customers);

  final List<Map<String, dynamic>> _customers;

  @override
  Future<List<Map<String, dynamic>>> getCustomersWithBarangay() async {
    return _customers;
  }
}

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
