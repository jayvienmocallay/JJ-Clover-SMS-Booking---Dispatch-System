part of 'database_helper.dart';

extension DatabasePrivacyOperations on DatabaseHelper {
  String _hashPhoneNumber(String phoneNumber) {
    final normalized = PhoneNumberUtils.normalize(phoneNumber);
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  Future<int> insertAuditLog({
    required String action,
    required String entityType,
    String? entityId,
    String? phoneNumber,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert('audit_logs', {
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'phone_hash': phoneNumber == null ? null : _hashPhoneNumber(phoneNumber),
      'metadata': metadata == null ? null : jsonEncode(metadata),
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int? limit}) async {
    final db = await DatabaseHelper.instance.database;
    return db.query('audit_logs', orderBy: 'created_at DESC', limit: limit);
  }

  Future<int> enqueueDeletionRetry({
    required String phoneNumber,
    String operation = 'customer_erasure',
    Object? lastError,
    DateTime? nextAttemptAt,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final normalized = PhoneNumberUtils.normalize(phoneNumber);
    final nowIso = DateTime.now().toIso8601String();
    final retryAt = (nextAttemptAt ?? DateTime.now()).toIso8601String();

    final existing = await db.query(
      'deletion_retry_queue',
      columns: ['id', 'attempts', 'created_at'],
      where: 'phone_number = ? AND operation = ? AND status IN (?, ?)',
      whereArgs: [normalized, operation, 'pending', 'failed'],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.single['id'] as int;
      await db.update(
        'deletion_retry_queue',
        {
          'status': 'pending',
          'last_error': lastError?.toString(),
          'next_attempt_at': retryAt,
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await insertAuditLog(
        action: 'deletion_retry_requeued',
        entityType: 'customer',
        phoneNumber: normalized,
        metadata: {'operation': operation},
      );
      return id;
    }

    final id = await db.insert('deletion_retry_queue', {
      'phone_number': normalized,
      'operation': operation,
      'status': 'pending',
      'attempts': 0,
      'last_error': lastError?.toString(),
      'next_attempt_at': retryAt,
      'created_at': nowIso,
      'updated_at': nowIso,
    });
    await insertAuditLog(
      action: 'deletion_retry_queued',
      entityType: 'customer',
      phoneNumber: normalized,
      metadata: {'operation': operation},
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> getDueDeletionRetries({
    DateTime? now,
    int limit = 20,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'deletion_retry_queue',
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

  Future<void> markDeletionRetrySucceeded(int id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'deletion_retry_queue',
      columns: ['phone_number', 'operation'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await db.update(
      'deletion_retry_queue',
      {
        'status': 'succeeded',
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      await insertAuditLog(
        action: 'deletion_retry_succeeded',
        entityType: 'customer',
        phoneNumber: rows.single['phone_number'] as String?,
        metadata: {'operation': rows.single['operation']},
      );
    }
  }

  Future<void> markDeletionRetryFailed(
    int id,
    Object error, {
    int maxAttempts = 8,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'deletion_retry_queue',
      columns: ['phone_number', 'operation', 'attempts'],
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
      'deletion_retry_queue',
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
    await insertAuditLog(
      action: status == 'abandoned'
          ? 'deletion_retry_abandoned'
          : 'deletion_retry_failed',
      entityType: 'customer',
      phoneNumber: rows.single['phone_number'] as String?,
      metadata: {'operation': rows.single['operation'], 'attempts': attempts},
    );
  }

  Future<int> applyRetentionPolicy({
    Duration smsRetention = const Duration(days: 90),
    Duration receiptRetention = const Duration(days: 30),
    Duration auditRetention = const Duration(days: 365),
    Duration deletionRetryRetention = const Duration(days: 30),
    DateTime? now,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final reference = now ?? DateTime.now();
    var deleted = 0;

    await db.transaction<void>((txn) async {
      final expiredSmsIds = await txn.query(
        'sms_messages',
        columns: ['id'],
        where: 'sent_at < ?',
        whereArgs: [reference.subtract(smsRetention).toIso8601String()],
      );
      deleted += await txn.delete(
        'sms_messages',
        where: 'sent_at < ?',
        whereArgs: [reference.subtract(smsRetention).toIso8601String()],
      );
      final nowIso = DateTime.now().toIso8601String();
      for (final row in expiredSmsIds) {
        final id = (row['id'] as num?)?.toInt();
        if (id == null) continue;
        await txn.insert('supabase_sync_deletions', {
          'table_name': 'sms_messages',
          'row_id': id,
          'status': 'pending',
          'attempts': 0,
          'next_attempt_at': nowIso,
          'created_at': nowIso,
          'updated_at': nowIso,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      deleted += await txn.delete(
        'incoming_sms_receipts',
        where: 'updated_at < ?',
        whereArgs: [reference.subtract(receiptRetention).toIso8601String()],
      );
      deleted += await txn.delete(
        'pending_sms_actions',
        where: 'updated_at < ?',
        whereArgs: [
          reference.subtract(const Duration(hours: 1)).toIso8601String(),
        ],
      );
      deleted += await txn.delete(
        'audit_logs',
        where: 'created_at < ?',
        whereArgs: [reference.subtract(auditRetention).toIso8601String()],
      );
      deleted += await txn.delete(
        'deletion_retry_queue',
        where: 'status = ? AND updated_at < ?',
        whereArgs: [
          'succeeded',
          reference.subtract(deletionRetryRetention).toIso8601String(),
        ],
      );
    });

    if (deleted > 0) {
      await insertAuditLog(
        action: 'retention_policy_applied',
        entityType: 'database',
        metadata: {'deleted_rows': deleted},
        createdAt: reference,
      );
    }
    return deleted;
  }

  Future<bool> deleteCustomerByPhone(String phoneNumber) async {
    final db = await DatabaseHelper.instance.database;
    final normalized = PhoneNumberUtils.normalize(phoneNumber);
    final customerRows = await db.query(
      'customers',
      columns: ['id'],
      where: 'contact_number = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    final customerId = customerRows.isEmpty
        ? null
        : customerRows.first['id'] as int;
    final orderRows = await db.query(
      'orders',
      columns: ['id'],
      where: customerId == null
          ? 'phone_number = ?'
          : 'customer_id = ? OR phone_number = ?',
      whereArgs: customerId == null ? [normalized] : [customerId, normalized],
    );
    final smsRows = await db.query(
      'sms_messages',
      columns: ['id'],
      where: 'phone_number = ?',
      whereArgs: [normalized],
    );

    await insertAuditLog(
      action: 'customer_erasure_requested',
      entityType: 'customer',
      phoneNumber: normalized,
    );

    final deleted = await db.transaction<bool>((txn) async {
      final rows = await txn.query(
        'customers',
        columns: ['id'],
        where: 'contact_number = ?',
        whereArgs: [normalized],
        limit: 1,
      );

      var deletedCustomer = false;
      if (rows.isNotEmpty) {
        final id = rows.first['id'] as int;
        // Anonymize historical orders so aggregate stats survive but no
        // personal identifiers remain (RA 10173 erasure of personal data).
        await txn.update(
          'orders',
          {'customer_id': null, 'phone_number': '', 'address': null},
          where: 'customer_id = ? OR phone_number = ?',
          whereArgs: [id, normalized],
        );
        await txn.delete('customers', where: 'id = ?', whereArgs: [id]);
        deletedCustomer = true;
      } else {
        // Even with no customer row, scrub any orders that referenced the
        // phone (walk-in DROP records etc.) so erasure is complete.
        await txn.update(
          'orders',
          {'phone_number': '', 'address': null},
          where: 'phone_number = ?',
          whereArgs: [normalized],
        );
      }

      await txn.delete(
        'sms_messages',
        where: 'phone_number = ?',
        whereArgs: [normalized],
      );
      await txn.delete(
        'incoming_sms_receipts',
        where: 'phone_number = ?',
        whereArgs: [normalized],
      );
      await txn.delete(
        'pending_sms_actions',
        where: 'phone_number = ?',
        whereArgs: [normalized],
      );

      return deletedCustomer;
    });

    await insertAuditLog(
      action: 'customer_erasure_local_completed',
      entityType: 'customer',
      phoneNumber: normalized,
      metadata: {'customer_deleted': deleted},
    );
    for (final row in orderRows) {
      final id = (row['id'] as num?)?.toInt();
      if (id != null) {
        await enqueueSupabaseSyncUpsert(tableName: 'orders', rowId: id);
      }
    }
    if (customerId != null && deleted) {
      await enqueueSupabaseSyncDeletion(
        tableName: 'customers',
        rowId: customerId,
      );
    }
    for (final row in smsRows) {
      final id = (row['id'] as num?)?.toInt();
      if (id != null) {
        await enqueueSupabaseSyncDeletion(tableName: 'sms_messages', rowId: id);
      }
    }
    return deleted;
  }
}
