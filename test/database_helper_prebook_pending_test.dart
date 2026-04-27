import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseHelper.databaseVersion,
        onConfigure: DatabaseHelper.configureDatabase,
        onCreate: DatabaseHelper.instance.createSchemaForTesting,
        singleInstance: false,
      ),
    );
    DatabaseHelper.setDatabaseForTesting(db);
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  test('stores pending pre-book contexts as JSON in app_settings', () async {
    const phone = '09171234567';
    const address = 'Purok 1~near pump | after green gate';
    final helper = DatabaseHelper.instance;

    await helper.setPreBookPending({
      phone: {
        'customerId': 12,
        'phoneNumber': phone,
        'quantity': 4,
        'gallonType': 'new',
        'address': address,
        'deliveryDay': 'Wednesday',
        'timestamp': 1770000000000,
      },
    });

    final raw = await helper.getSetting(DatabaseHelper.preBookPendingKey);
    expect(raw, isNotNull);

    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    final context = decoded[phone] as Map<String, dynamic>;
    expect(context['address'], address);

    final pending = await helper.getPreBookPending();
    expect(pending[phone]?['customerId'], 12);
    expect(pending[phone]?['quantity'], 4);
    expect(pending[phone]?['gallonType'], 'new');
    expect(pending[phone]?['address'], address);
    expect(pending[phone]?['deliveryDay'], 'Wednesday');
    expect(pending[phone]?['timestamp'], 1770000000000);
  });

  test(
    'migrates the legacy delimiter format when reading pending pre-books',
    () async {
      const phone = '09170000001';
      const address = 'Sitio A~near tank | after corner';
      const legacyValue = '$phone~7~3~old~$address~Monday~1770000000001';
      final helper = DatabaseHelper.instance;

      await helper.setSetting(DatabaseHelper.preBookPendingKey, legacyValue);

      final pending = await helper.getPreBookPending();
      expect(pending[phone]?['customerId'], 7);
      expect(pending[phone]?['quantity'], 3);
      expect(pending[phone]?['gallonType'], 'old');
      expect(pending[phone]?['address'], address);
      expect(pending[phone]?['deliveryDay'], 'Monday');
      expect(pending[phone]?['timestamp'], 1770000000001);

      final migratedRaw = await helper.getSetting(
        DatabaseHelper.preBookPendingKey,
      );
      final migrated = jsonDecode(migratedRaw!) as Map<String, dynamic>;
      expect((migrated[phone] as Map<String, dynamic>)['address'], address);
    },
  );
}
