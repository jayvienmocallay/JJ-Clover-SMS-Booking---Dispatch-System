import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/providers/customer_provider.dart';
import 'package:jj_clover_sms/data/repositories/customer_repository.dart';
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

  test(
    'deleteCustomer returns false when no customer rows are affected',
    () async {
      final provider = CustomerProvider(CustomerRepository());

      final deleted = await provider.deleteCustomer(999999);

      expect(deleted, isFalse);
      expect(provider.error, 'No customer was deleted.');

      provider.dispose();
    },
  );

  test(
    'updateCustomer returns false when no customer rows are affected',
    () async {
      final provider = CustomerProvider(CustomerRepository());

      final updated = await provider.updateCustomer(999999, {
        'name': 'Missing Customer',
        'contact_number': '09170000000',
        'barangay_id': 1,
      });

      expect(updated, isFalse);
      expect(provider.error, 'No customer was updated.');

      provider.dispose();
    },
  );
}
