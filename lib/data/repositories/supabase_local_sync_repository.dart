import '../../database_helper.dart';

class SupabaseLocalSyncRepository {
  static const Set<String> allowedSyncTables = {
    'barangays',
    'customers',
    'orders',
    'sms_messages',
  };

  Future<List<Map<String, dynamic>>> getRowsForSync(String tableName) async {
    _assertAllowedSyncTable(tableName);
    final db = await DatabaseHelper.instance.database;
    return db.query(tableName, orderBy: 'id ASC');
  }

  Future<int> countRows(String tableName) async {
    _assertAllowedSyncTable(tableName);
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM $tableName');
    final count = result.first['cnt'];
    return count is int ? count : int.tryParse('$count') ?? 0;
  }

  void _assertAllowedSyncTable(String tableName) {
    if (!allowedSyncTables.contains(tableName)) {
      throw ArgumentError('Table is not allowed for Supabase sync: $tableName');
    }
  }
}
