import '../../database_helper.dart';

class SupabaseLocalSyncRepository {
  Future<List<Map<String, dynamic>>> getRowsForSync(String tableName) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(tableName, orderBy: 'id ASC');
  }

  Future<int> countRows(String tableName) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM $tableName');
    final count = result.first['cnt'];
    return count is int ? count : int.tryParse('$count') ?? 0;
  }
}
