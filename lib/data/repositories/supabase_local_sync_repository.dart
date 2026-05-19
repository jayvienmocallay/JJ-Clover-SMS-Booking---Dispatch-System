import '../../database_helper.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

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

  Future<int> mergeRemoteRows(
    String tableName,
    List<Map<String, dynamic>> rows, {
    Set<int> excludedIds = const <int>{},
  }) async {
    _assertAllowedSyncTable(tableName);
    if (rows.isEmpty) return 0;

    final db = await DatabaseHelper.instance.database;
    var inserted = 0;
    await db.transaction<void>((txn) async {
      for (final row in rows) {
        final rowId = (row['id'] as num?)?.toInt();
        if (rowId == null || excludedIds.contains(rowId)) continue;

        final sanitized = Map<String, dynamic>.from(row);
        final id = await txn.insert(
          tableName,
          sanitized,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (id != 0) inserted++;
      }
    });
    return inserted;
  }

  Future<Set<int>> pendingDeletedRowIds(String tableName) {
    _assertAllowedSyncTable(tableName);
    return DatabaseHelper.instance.getPendingSupabaseSyncDeletionIds(tableName);
  }

  Future<List<Map<String, dynamic>>> dueDeletedRows({int limit = 50}) {
    return DatabaseHelper.instance.getDueSupabaseSyncDeletions(limit: limit);
  }

  Future<void> markDeletedRowSynced(int id) {
    return DatabaseHelper.instance.markSupabaseSyncDeletionSucceeded(id);
  }

  Future<void> markDeletedRowFailed(int id, Object error) {
    return DatabaseHelper.instance.markSupabaseSyncDeletionFailed(id, error);
  }

  void _assertAllowedSyncTable(String tableName) {
    if (!allowedSyncTables.contains(tableName)) {
      throw ArgumentError('Table is not allowed for Supabase sync: $tableName');
    }
  }
}
