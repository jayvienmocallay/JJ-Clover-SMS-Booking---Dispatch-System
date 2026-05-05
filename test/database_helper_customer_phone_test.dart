import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late int barangayId;

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

    final barangay = (await db.query(
      'barangays',
      where: 'name = ?',
      whereArgs: ['San Isidro'],
      limit: 1,
    )).single;
    barangayId = barangay['id'] as int;
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  Map<String, dynamic> customerData(String name, String phone) {
    return {
      'name': name,
      'contact_number': phone,
      'address': 'Purok 1',
      'barangay_id': barangayId,
    };
  }

  test('fresh schema has a unique customer phone index', () async {
    final indexes = await db.rawQuery('PRAGMA index_list(customers)');

    expect(
      indexes,
      contains(
        allOf(
          containsPair('name', 'idx_customers_contact_number_unique'),
          containsPair('unique', 1),
        ),
      ),
    );
  });

  test('insertCustomer normalizes contact_number before storing', () async {
    final helper = DatabaseHelper.instance;

    final customerId = await helper.insertCustomer(
      customerData('Normalized Insert', '+63 917-123-4567'),
    );

    final row = (await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
    )).single;
    expect(row['contact_number'], '09171234567');
  });

  test('duplicate normalized customer phone inserts are rejected', () async {
    final helper = DatabaseHelper.instance;
    await helper.insertCustomer(customerData('First Customer', '09171234567'));

    await expectLater(
      helper.insertCustomer(
        customerData('Duplicate Customer', '+639171234567'),
      ),
      throwsA(
        isA<CustomerPhoneAlreadyExistsException>().having(
          (error) => error.contactNumber,
          'contactNumber',
          '09171234567',
        ),
      ),
    );
  });

  test('updateCustomer normalizes contact_number before storing', () async {
    final helper = DatabaseHelper.instance;
    final customerId = await helper.insertCustomer(
      customerData('Needs Update', '09171234567'),
    );

    await helper.updateCustomer(customerId, {
      'name': 'Needs Update',
      'contact_number': '+63 918-123-4567',
      'address': 'Purok 2',
      'barangay_id': barangayId,
    });

    final row = (await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
    )).single;
    expect(row['contact_number'], '09181234567');
  });

  test('duplicate normalized customer phone updates are rejected', () async {
    final helper = DatabaseHelper.instance;
    await helper.insertCustomer(customerData('First Customer', '09171234567'));
    final secondId = await helper.insertCustomer(
      customerData('Second Customer', '09181234567'),
    );

    await expectLater(
      helper.updateCustomer(secondId, {
        'name': 'Second Customer',
        'contact_number': '+639171234567',
        'address': 'Purok 2',
        'barangay_id': barangayId,
      }),
      throwsA(
        isA<CustomerPhoneAlreadyExistsException>().having(
          (error) => error.contactNumber,
          'contactNumber',
          '09171234567',
        ),
      ),
    );
  });

  test(
    'v5 migration normalizes existing customer phones and creates index',
    () async {
      final legacyDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(legacyDb.close);

      await _createLegacyCustomerPhoneTables(legacyDb);
      await legacyDb.insert('customers', {
        'name': 'Legacy Customer',
        'contact_number': '+63 917-123-4567',
        'address': 'Purok 1',
        'barangay_id': 1,
      });

      await DatabaseHelper.instance.upgradeSchemaForTesting(
        legacyDb,
        4,
        DatabaseHelper.databaseVersion,
      );

      final row = (await legacyDb.query('customers')).single;
      expect(row['contact_number'], '09171234567');

      final indexes = await legacyDb.rawQuery('PRAGMA index_list(customers)');
      expect(
        indexes,
        contains(
          allOf(
            containsPair('name', 'idx_customers_contact_number_unique'),
            containsPair('unique', 1),
          ),
        ),
      );
    },
  );

  test(
    'v5 migration fails safely when normalized customer phones collide',
    () async {
      final legacyDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(legacyDb.close);

      await _createLegacyCustomerPhoneTables(legacyDb);
      await legacyDb.insert('customers', {
        'id': 1,
        'name': 'Legacy Local',
        'contact_number': '09171234567',
        'address': 'Purok 1',
        'barangay_id': 1,
      });
      await legacyDb.insert('customers', {
        'id': 2,
        'name': 'Legacy International',
        'contact_number': '+639171234567',
        'address': 'Purok 2',
        'barangay_id': 1,
      });

      await expectLater(
        DatabaseHelper.instance.upgradeSchemaForTesting(
          legacyDb,
          4,
          DatabaseHelper.databaseVersion,
        ),
        throwsA(
          isA<CustomerPhoneIdentityMigrationException>()
              .having(
                (error) => error.toString(),
                'message',
                contains('09171234567'),
              )
              .having(
                (error) => error.toString(),
                'message',
                contains('customer IDs 1, 2'),
              ),
        ),
      );
    },
  );
}

Future<void> _createLegacyCustomerPhoneTables(Database db) async {
  await db.execute('''
    CREATE TABLE barangays (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      delivery_zone TEXT NOT NULL
    )
  ''');
  await db.insert('barangays', {
    'id': 1,
    'name': 'San Isidro',
    'delivery_zone': 'Zone A',
  });
  await db.execute('''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      contact_number TEXT NOT NULL,
      address TEXT,
      barangay_id INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT
    )
  ''');
  await db.execute('''
    CREATE TABLE delivery_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      customer_id INTEGER NOT NULL,
      staff_id INTEGER,
      quantity_delivered INTEGER NOT NULL,
      gallon_type TEXT,
      notes TEXT,
      delivered_at TEXT NOT NULL
    )
  ''');
}
