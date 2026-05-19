part of 'database_helper.dart';

extension DatabaseSyncOperations on DatabaseHelper {
  static const Set<String> _allowedSupabaseSyncTables = {
    'barangays',
    'customers',
    'orders',
    'sms_messages',
  };

  void _assertAllowedSupabaseSyncTable(String tableName) {
    if (!_allowedSupabaseSyncTables.contains(tableName)) {
      throw ArgumentError('Table is not allowed for Supabase sync: $tableName');
    }
  }

  Future<int> enqueueSupabaseSyncDeletion({
    required String tableName,
    required int rowId,
    Object? lastError,
    DateTime? nextAttemptAt,
  }) async {
    _assertAllowedSupabaseSyncTable(tableName);
    final db = await DatabaseHelper.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final retryAt = (nextAttemptAt ?? DateTime.now()).toIso8601String();

    final existing = await db.query(
      'supabase_sync_deletions',
      columns: ['id'],
      where: 'table_name = ? AND row_id = ? AND status IN (?, ?)',
      whereArgs: [tableName, rowId, 'pending', 'failed'],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.single['id'] as int;
      await db.update(
        'supabase_sync_deletions',
        {
          'status': 'pending',
          'last_error': lastError?.toString(),
          'next_attempt_at': retryAt,
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }

    return db.insert('supabase_sync_deletions', {
      'table_name': tableName,
      'row_id': rowId,
      'status': 'pending',
      'attempts': 0,
      'last_error': lastError?.toString(),
      'next_attempt_at': retryAt,
      'created_at': nowIso,
      'updated_at': nowIso,
    });
  }

  Future<List<Map<String, dynamic>>> getDueSupabaseSyncDeletions({
    DateTime? now,
    int limit = 50,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'supabase_sync_deletions',
      where: 'status IN (?, ?) AND next_attempt_at <= ?',
      whereArgs: [
        'pending',
        'failed',
        (now ?? DateTime.now()).toIso8601String(),
      ],
      orderBy: 'next_attempt_at ASC, id ASC',
      limit: limit,
    );
  }

  Future<Set<int>> getPendingSupabaseSyncDeletionIds(String tableName) async {
    _assertAllowedSupabaseSyncTable(tableName);
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'supabase_sync_deletions',
      columns: ['row_id'],
      where: 'table_name = ? AND status IN (?, ?)',
      whereArgs: [tableName, 'pending', 'failed'],
    );
    return rows
        .map((row) => (row['row_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
  }

  Future<void> markSupabaseSyncDeletionSucceeded(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'supabase_sync_deletions',
      {
        'status': 'succeeded',
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSupabaseSyncDeletionFailed(
    int id,
    Object error, {
    int maxAttempts = 8,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'supabase_sync_deletions',
      columns: ['attempts'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final currentAttempts = (rows.single['attempts'] as num?)?.toInt() ?? 0;
    final attempts = currentAttempts + 1;
    final status = attempts >= maxAttempts ? 'abandoned' : 'failed';
    final backoffHours = attempts >= 6 ? 24 : 1 << (attempts - 1);
    final now = DateTime.now();
    await db.update(
      'supabase_sync_deletions',
      {
        'status': status,
        'attempts': attempts,
        'last_error': error.toString(),
        'next_attempt_at': now
            .add(Duration(hours: backoffHours))
            .toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
