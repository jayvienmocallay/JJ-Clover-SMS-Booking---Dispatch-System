part of 'database_helper.dart';

extension DatabaseSmsOperations on DatabaseHelper {
  Future<({bool claimed, bool isDuplicate})> claimIncomingSmsReceipt({
    required String messageId,
    required String phoneNumber,
    required String message,
    int? smsTimestamp,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);

    return await db.transaction<({bool claimed, bool isDuplicate})>((
      txn,
    ) async {
      final existing = await txn.query(
        'incoming_sms_receipts',
        where: 'message_id = ?',
        whereArgs: [messageId],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert('incoming_sms_receipts', {
          'message_id': messageId,
          'phone_number': normalizedPhone,
          'message': message,
          'sms_timestamp': smsTimestamp,
          'status': 'processing',
          'attempts': 1,
          'received_at': nowIso,
          'claimed_at': nowIso,
          'updated_at': nowIso,
        });
        return (claimed: true, isDuplicate: false);
      }

      final row = existing.first;
      final status = row['status'] as String? ?? '';
      final completedAt = _tryParseDate(row['completed_at'] as String?);

      // If completed, check if within resubmit cooldown (1 hour)
      if (status == 'completed' && completedAt != null) {
        final timeSinceCompletion = now.difference(completedAt);
        if (timeSinceCompletion < DatabaseHelper._resubmitCooldownAfter) {
          return (claimed: false, isDuplicate: true);
        }
        // After 1 hour, allow resubmit â€” treat as new message
        await txn.update(
          'incoming_sms_receipts',
          {
            'status': 'processing',
            'attempts': 1,
            'received_at': nowIso,
            'claimed_at': nowIso,
            'updated_at': nowIso,
            'completed_at': null,
            'last_error': null,
          },
          where: 'message_id = ?',
          whereArgs: [messageId],
        );
        return (claimed: true, isDuplicate: false);
      }

      // If still processing within 10-min retry window, skip retry
      if (status == 'processing') {
        final claimedAt = _tryParseDate(row['claimed_at'] as String?);
        if (claimedAt != null &&
            now.difference(claimedAt) < DatabaseHelper._receiptRetryAfter) {
          return (claimed: false, isDuplicate: false);
        }
      }

      // Retry after 10 min (but before 1 hour) â€” reprocess idempotently
      final attempts = (row['attempts'] as num?)?.toInt() ?? 0;
      await txn.update(
        'incoming_sms_receipts',
        {
          'phone_number': normalizedPhone,
          'message': message,
          'sms_timestamp': smsTimestamp,
          'status': 'processing',
          'attempts': attempts + 1,
          'claimed_at': nowIso,
          'updated_at': nowIso,
          'last_error': null,
        },
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
      return (claimed: true, isDuplicate: false);
    });
  }

  Future<void> completeIncomingSmsReceipt(String messageId) async {
    final db = await DatabaseHelper.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    await db.update(
      'incoming_sms_receipts',
      {
        'status': 'completed',
        'completed_at': nowIso,
        'updated_at': nowIso,
        'last_error': null,
      },
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> failIncomingSmsReceipt(String messageId, Object error) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'incoming_sms_receipts',
      {
        'status': 'failed',
        'updated_at': DateTime.now().toIso8601String(),
        'last_error': error.toString(),
      },
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<Map<String, dynamic>?> getIncomingSmsReceipt(String messageId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'incoming_sms_receipts',
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Insert an SMS message (incoming or outgoing)
  Future<int> insertSmsMessage(Map<String, dynamic> messageData) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedData = Map<String, dynamic>.from(messageData);
    final phoneNumber = normalizedData['phone_number'] as String?;
    if (phoneNumber != null) {
      normalizedData['phone_number'] = PhoneNumberUtils.normalize(phoneNumber);
    }
    final id = await db.insert('sms_messages', normalizedData);
    await enqueueSupabaseSyncUpsert(tableName: 'sms_messages', rowId: id);
    return id;
  }

  /// Get all SMS messages for a phone number
  Future<List<Map<String, dynamic>>> getSmsMessagesForPhone(
    String phoneNumber, {
    int? limit,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    return await db.query(
      'sms_messages',
      where: 'phone_number = ?',
      whereArgs: [normalizedPhone],
      orderBy: 'sent_at DESC',
      limit: limit,
    );
  }

  /// Get all SMS messages, newest first
  Future<List<Map<String, dynamic>>> getAllSmsMessages({int? limit}) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'sms_messages',
      orderBy: 'sent_at DESC',
      limit: limit,
    );
  }

  /// Get all SMS messages for today
  Future<List<Map<String, dynamic>>> getTodaySmsMessages() async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await db.query(
      'sms_messages',
      where: 'date(sent_at) = ?',
      whereArgs: [today],
      orderBy: 'sent_at DESC',
    );
  }
}
