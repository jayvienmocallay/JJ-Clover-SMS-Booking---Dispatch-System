import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/models/order_model.dart';
import 'package:jj_clover_sms/data/repositories/order_repository.dart';
import 'package:jj_clover_sms/database_helper.dart';
import 'package:jj_clover_sms/ui/theme/app_theme.dart';
import 'package:jj_clover_sms/ui/widgets/order_card.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Database? db;

  setUpAll(sqfliteFfiInit);

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    await db?.close();
  });

  testWidgets('completed order detail view shows the delivery log', (
    tester,
  ) async {
    late Map<String, dynamic> orderMap;

    await tester.runAsync(() async {
      final testDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseHelper.databaseVersion,
          onConfigure: DatabaseHelper.configureDatabase,
          onCreate: DatabaseHelper.instance.createSchemaForTesting,
          singleInstance: false,
        ),
      );
      db = testDb;
      DatabaseHelper.setDatabaseForTesting(testDb);

      final helper = DatabaseHelper.instance;
      final barangay = (await testDb.query(
        'barangays',
        where: 'name = ?',
        whereArgs: ['San Isidro'],
        limit: 1,
      )).single;

      final customerId = await helper.insertCustomer({
        'name': 'Detail View Customer',
        'contact_number': '09181112222',
        'address': 'Purok 3',
        'barangay_id': barangay['id'],
      });
      final orderId = await helper.insertOrder({
        'customer_id': customerId,
        'phone_number': '09181112222',
        'type': 'deliver',
        'quantity': 2,
        'gallon_type': 'new',
        'address': 'Purok 3',
        'status': 'in_transit',
        'created_at': DateTime(2026, 4, 26, 8).toIso8601String(),
        'delivery_day': 'Monday',
        'is_pre_book': 0,
      });
      await helper.updateOrderStatus(
        orderId,
        'completed',
        notes: 'Gate handoff',
        deliveredAt: DateTime(2026, 4, 26, 9, 30),
      );

      orderMap = (await testDb.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
      )).single;
    });

    await tester.pumpWidget(
      Provider<OrderRepository>(
        create: (_) => OrderRepository(),
        child: MaterialApp(
          theme: _testTheme,
          home: Scaffold(
            body: OrderCard(
              order: Order.fromMap(orderMap),
              customerName: 'Detail View Customer',
              phone: '09181112222',
              barangay: 'San Isidro',
              address: 'Purok 3',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('View Delivery Log'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Delivery Log'), findsOneWidget);
    expect(find.text('2 gallons delivered (new)'), findsOneWidget);
    expect(find.text('Gate handoff'), findsOneWidget);
    expect(find.text('9:30 AM'), findsOneWidget);
  });
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
