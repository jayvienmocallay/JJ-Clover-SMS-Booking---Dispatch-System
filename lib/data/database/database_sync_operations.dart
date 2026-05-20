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

  Future<int> enqueueSupabaseSyncUpsert({
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
      'supabase_sync_upserts',
      columns: ['id'],
      where: 'table_name = ? AND row_id = ? AND status IN (?, ?)',
      whereArgs: [tableName, rowId, 'pending', 'failed'],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.single['id'] as int;
      await db.update(
        'supabase_sync_upserts',
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

    return db.insert('supabase_sync_upserts', {
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

  Future<List<Map<String, dynamic>>> getDueSupabaseSyncUpserts({
    required String tableName,
    DateTime? now,
    int limit = 200,
  }) async {
    _assertAllowedSupabaseSyncTable(tableName);
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'supabase_sync_upserts',
      where: 'table_name = ? AND status IN (?, ?) AND next_attempt_at <= ?',
      whereArgs: [
        tableName,
        'pending',
        'failed',
        (now ?? DateTime.now()).toIso8601String(),
      ],
      orderBy: 'next_attempt_at ASC, id ASC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getRowsByIdsForSupabaseSync(
    String tableName,
    Set<int> rowIds,
  ) async {
    _assertAllowedSupabaseSyncTable(tableName);
    if (rowIds.isEmpty) return const [];
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(rowIds.length, '?').join(', ');
    return db.query(
      tableName,
      where: 'id IN ($placeholders)',
      whereArgs: rowIds.toList(),
      orderBy: 'id ASC',
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

  Future<void> markSupabaseSyncUpsertsSucceeded(Iterable<int> ids) async {
    final idList = ids.toList();
    if (idList.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(idList.length, '?').join(', ');
    await db.update(
      'supabase_sync_upserts',
      {
        'status': 'succeeded',
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id IN ($placeholders)',
      whereArgs: idList,
    );
  }

  Future<void> markSupabaseSyncUpsertRowsSucceeded(
    String tableName,
    Iterable<int> rowIds,
  ) async {
    _assertAllowedSupabaseSyncTable(tableName);
    final rowIdList = rowIds.toList();
    if (rowIdList.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(rowIdList.length, '?').join(', ');
    await db.update(
      'supabase_sync_upserts',
      {
        'status': 'succeeded',
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where:
          'table_name = ? AND row_id IN ($placeholders) AND status IN (?, ?)',
      whereArgs: [tableName, ...rowIdList, 'pending', 'failed'],
    );
  }

  Future<void> markSupabaseSyncUpsertFailed(
    int id,
    Object error, {
    int maxAttempts = 8,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'supabase_sync_upserts',
      columns: ['attempts'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final currentAttempts = (rows.single['attempts'] as num?)?.toInt() ?? 0;
    final attempts = currentAttempts + 1;
    final status = attempts >= maxAttempts ? 'abandoned' : 'failed';
    final backoffMinutes = attempts >= 6 ? 60 : 1 << (attempts - 1);
    final now = DateTime.now();
    await db.update(
      'supabase_sync_upserts',
      {
        'status': status,
        'attempts': attempts,
        'last_error': error.toString(),
        'next_attempt_at': now
            .add(Duration(minutes: backoffMinutes))
            .toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getSupabaseSyncLastRemoteId(String tableName) async {
    _assertAllowedSupabaseSyncTable(tableName);
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'supabase_sync_state',
      columns: ['last_remote_id'],
      where: 'table_name = ?',
      whereArgs: [tableName],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.single['last_remote_id'] as num?)?.toInt() ?? 0;
  }

  Future<bool> isSupabaseSyncBaselineUploaded(String tableName) async {
    _assertAllowedSupabaseSyncTable(tableName);
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'supabase_sync_state',
      columns: ['baseline_uploaded'],
      where: 'table_name = ?',
      whereArgs: [tableName],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return ((rows.single['baseline_uploaded'] as num?)?.toInt() ?? 0) == 1;
  }

  Future<void> saveSupabaseSyncState(
    String tableName, {
    int? lastRemoteId,
    bool? baselineUploaded,
  }) async {
    _assertAllowedSupabaseSyncTable(tableName);
    final db = await DatabaseHelper.instance.database;
    final existing = await db.query(
      'supabase_sync_state',
      columns: ['last_remote_id', 'baseline_uploaded'],
      where: 'table_name = ?',
      whereArgs: [tableName],
      limit: 1,
    );
    final current = existing.isEmpty ? null : existing.single;
    final data = {
      'table_name': tableName,
      'last_remote_id':
          lastRemoteId ??
          (current == null
              ? 0
              : (current['last_remote_id'] as num?)?.toInt() ?? 0),
      'baseline_uploaded': baselineUploaded == null
          ? (current == null
                ? 0
                : (current['baseline_uploaded'] as num?)?.toInt() ?? 0)
          : (baselineUploaded ? 1 : 0),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await db.insert(
      'supabase_sync_state',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
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
