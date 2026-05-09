import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/utils/phone_number_utils.dart';
import '../../database_helper.dart';

class OutgoingSmsQueueRepository {
  static const String statusPending = 'pending';
  static const String statusSending = 'sending';
  static const String statusSent = 'sent';
  static const String statusFailed = 'failed';

  static const int maxAttempts = 3;

  static const Duration duplicateWindow = Duration(minutes: 5);
  static const Duration sendingStaleAfter = Duration(minutes: 2);

  Future<Database> get _db async {
    final db = await DatabaseHelper.instance.database;
    await ensureTable(db);
    return db;
  }

  static Future<void> ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outgoing_sms_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone_number TEXT NOT NULL,
        message TEXT NOT NULL,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        next_attempt_at TEXT NOT NULL,
        sent_at TEXT,
        last_error TEXT,
        source_message_id TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outgoing_sms_status_next '
      'ON outgoing_sms_queue(status, next_attempt_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outgoing_sms_phone_created '
      'ON outgoing_sms_queue(phone_number, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_outgoing_sms_source '
      'ON outgoing_sms_queue(source_message_id)',
    );
  }

  Future<int?> enqueue({
    required String phoneNumber,
    required String message,
    String? sourceMessageId,
    DateTime? nextAttemptAt,
  }) async {
    final db = await _db;
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final duplicateCutoff = now.subtract(duplicateWindow).toIso8601String();

    final duplicates = await db.query(
      'outgoing_sms_queue',
      columns: ['id'],
      where: 'phone_number = ? AND message = ? AND created_at >= ? AND status IN (?, ?, ?)',
      whereArgs: [
        normalizedPhone,
        message,
        duplicateCutoff,
        statusPending,
        statusSending,
        statusSent,
      ],
      limit: 1,
    );
    if (duplicates.isNotEmpty) return null;

    return db.insert('outgoing_sms_queue', {
      'phone_number': normalizedPhone,
      'message': message,
      'status': statusPending,
      'attempts': 0,
      'created_at': nowIso,
      'updated_at': nowIso,
      'next_attempt_at': (nextAttemptAt ?? now).toIso8601String(),
      'source_message_id': sourceMessageId,
    });
  }

  Future<Map<String, dynamic>?> claimNextDue() async {
    final db = await _db;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final staleCutoff = now.subtract(sendingStaleAfter).toIso8601String();

    return db.transaction<Map<String, dynamic>?>((txn) async {
      await txn.update(
        'outgoing_sms_queue',
        {
          'status': statusPending,
          'updated_at': nowIso,
          'last_error': 'Recovered stale sending row',
        },
        where: 'status = ? AND updated_at < ? AND attempts < ?',
        whereArgs: [statusSending, staleCutoff, maxAttempts],
      );

      final rows = await txn.query(
        'outgoing_sms_queue',
        where: 'status = ? AND next_attempt_at <= ? AND attempts < ?',
        whereArgs: [statusPending, nowIso, maxAttempts],
        orderBy: 'next_attempt_at ASC, created_at ASC, id ASC',
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      final id = row['id'] as int;
      final attempts = (row['attempts'] as num?)?.toInt() ?? 0;
      await txn.update(
        'outgoing_sms_queue',
        {
          'status': statusSending,
          'attempts': attempts + 1,
          'updated_at': nowIso,
          'last_error': null,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, statusPending],
      );

      final claimedRows = await txn.query(
        'outgoing_sms_queue',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return claimedRows.isEmpty ? null : claimedRows.first;
    });
  }

  Future<void> markSent(int id) async {
    final db = await _db;
    final nowIso = DateTime.now().toIso8601String();
    await db.update(
      'outgoing_sms_queue',
      {
        'status': statusSent,
        'sent_at': nowIso,
        'updated_at': nowIso,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailedOrRetry(int id, Object error) async {
    final db = await _db;
    final rows = await db.query(
      'outgoing_sms_queue',
      columns: ['attempts'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final attempts = (rows.first['attempts'] as num?)?.toInt() ?? 0;
    final retryDelay = _retryDelayForAttempt(attempts);
    final terminal = attempts >= maxAttempts;
    final now = DateTime.now();
    await db.update(
      'outgoing_sms_queue',
      {
        'status': terminal ? statusFailed : statusPending,
        'updated_at': now.toIso8601String(),
        'next_attempt_at': (terminal ? now : now.add(retryDelay)).toIso8601String(),
        'last_error': error.toString(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getRecent({int limit = 50}) async {
    final db = await _db;
    return db.query(
      'outgoing_sms_queue',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<DateTime?> getNextPendingAttemptAt() async {
    final db = await _db;
    final rows = await db.query(
      'outgoing_sms_queue',
      columns: ['next_attempt_at'],
      where: 'status = ? AND attempts < ?',
      whereArgs: [statusPending, maxAttempts],
      orderBy: 'next_attempt_at ASC, created_at ASC, id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final value = rows.first['next_attempt_at'] as String?;
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> deleteForPhoneNumber(String phoneNumber) async {
    final db = await _db;
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    await db.delete(
      'outgoing_sms_queue',
      where: 'phone_number = ?',
      whereArgs: [normalizedPhone],
    );
  }

  Duration _retryDelayForAttempt(int attempts) {
    switch (attempts) {
      case 0:
      case 1:
        return const Duration(seconds: 30);
      case 2:
        return const Duration(minutes: 2);
      default:
        return const Duration(minutes: 10);
    }
  }
}
