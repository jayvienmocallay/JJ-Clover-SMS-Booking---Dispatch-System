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

  Future<List<Map<String, dynamic>>> getRowsByIds(
    String tableName,
    Set<int> rowIds,
  ) {
    _assertAllowedSyncTable(tableName);
    return DatabaseHelper.instance.getRowsByIdsForSupabaseSync(
      tableName,
      rowIds,
    );
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

  Future<List<Map<String, dynamic>>> dueUpsertRows(
    String tableName, {
    int limit = 200,
  }) {
    _assertAllowedSyncTable(tableName);
    return DatabaseHelper.instance.getDueSupabaseSyncUpserts(
      tableName: tableName,
      limit: limit,
    );
  }

  Future<void> markDeletedRowSynced(int id) {
    return DatabaseHelper.instance.markSupabaseSyncDeletionSucceeded(id);
  }

  Future<void> markDeletedRowFailed(int id, Object error) {
    return DatabaseHelper.instance.markSupabaseSyncDeletionFailed(id, error);
  }

  Future<void> markUpsertsSucceeded(Iterable<int> ids) {
    return DatabaseHelper.instance.markSupabaseSyncUpsertsSucceeded(ids);
  }

  Future<void> markUpsertRowsSucceeded(String tableName, Iterable<int> rowIds) {
    _assertAllowedSyncTable(tableName);
    return DatabaseHelper.instance.markSupabaseSyncUpsertRowsSucceeded(
      tableName,
      rowIds,
    );
  }

  Future<void> markUpsertFailed(int id, Object error) {
    return DatabaseHelper.instance.markSupabaseSyncUpsertFailed(id, error);
  }

  Future<int> lastRemoteId(String tableName) {
    _assertAllowedSyncTable(tableName);
    return DatabaseHelper.instance.getSupabaseSyncLastRemoteId(tableName);
  }

  Future<bool> isBaselineUploaded(String tableName) {
    _assertAllowedSyncTable(tableName);
    return DatabaseHelper.instance.isSupabaseSyncBaselineUploaded(tableName);
  }

  Future<void> saveSyncState(
    String tableName, {
    int? lastRemoteId,
    bool? baselineUploaded,
  }) {
    _assertAllowedSyncTable(tableName);
    return DatabaseHelper.instance.saveSupabaseSyncState(
      tableName,
      lastRemoteId: lastRemoteId,
      baselineUploaded: baselineUploaded,
    );
  }

  void _assertAllowedSyncTable(String tableName) {
    if (!allowedSyncTables.contains(tableName)) {
      throw ArgumentError('Table is not allowed for Supabase sync: $tableName');
    }
  }
}
