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

  test('getOrderHistory filters by date, status, type, and search', () async {
    final helper = DatabaseHelper.instance;
    final mayOne = DateTime(2026, 5, 1, 8);
    final mayTwo = DateTime(2026, 5, 2, 8);

    final targetId = await helper.insertOrder({
      'phone_number': '09171110000',
      'type': 'deliver',
      'quantity': 3,
      'gallon_type': 'new',
      'status': 'completed',
      'created_at': mayOne.toIso8601String(),
      'scheduled_for': mayOne.toIso8601String(),
      'is_pre_book': 0,
      'source': 'manual',
    });
    await helper.insertOrder({
      'phone_number': '09172220000',
      'type': 'drop',
      'quantity': 1,
      'gallon_type': 'old',
      'status': 'pending',
      'created_at': mayTwo.toIso8601String(),
      'scheduled_for': mayTwo.toIso8601String(),
      'is_pre_book': 0,
      'source': 'sms',
    });

    final rows = await helper.getOrderHistory(
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 2),
      status: 'completed',
      type: 'deliver',
      search: '09171110000',
    );

    expect(rows, hasLength(1));
    expect(rows.single['id'], targetId);
    expect(rows.single['source'], 'manual');
  });

  test('getOrderHistory sorts newest first', () async {
    final helper = DatabaseHelper.instance;

    final olderId = await helper.insertOrder({
      'phone_number': '09173330000',
      'type': 'drop',
      'quantity': 1,
      'status': 'pending',
      'created_at': DateTime(2026, 5, 1, 8).toIso8601String(),
      'is_pre_book': 0,
      'source': 'manual',
    });
    final newerId = await helper.insertOrder({
      'phone_number': '09174440000',
      'type': 'drop',
      'quantity': 1,
      'status': 'pending',
      'created_at': DateTime(2026, 5, 2, 8).toIso8601String(),
      'is_pre_book': 0,
      'source': 'sms',
    });

    final rows = await helper.getOrderHistory();

    expect(rows.map((row) => row['id']).toList(), [newerId, olderId]);
  });
}
