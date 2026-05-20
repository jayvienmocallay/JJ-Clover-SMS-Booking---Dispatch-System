import '../../core/utils/phone_number_utils.dart';
import '../../database_helper.dart';

class SmsMessageRepository {
  Future<List<Map<String, dynamic>>> getSmsMessagesForPhone(
    String phoneNumber, {
    int? limit,
  }) {
    return DatabaseHelper.instance.getSmsMessagesForPhone(
      phoneNumber,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getAllSmsMessages({int? limit}) {
    return DatabaseHelper.instance.getAllSmsMessages(limit: limit);
  }

  Future<int> insertSmsMessage(Map<String, dynamic> data) {
    return DatabaseHelper.instance.insertSmsMessage(data);
  }

  Future<int> updateSmsMessageStatus(int id, String status) async {
    final db = await DatabaseHelper.instance.database;
    final updated = await db.update(
      'sms_messages',
      {'status': status, 'sent_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated > 0) {
      await DatabaseHelper.instance.enqueueSupabaseSyncUpsert(
        tableName: 'sms_messages',
        rowId: id,
      );
    }
    return updated;
  }

  Future<int> updateSmsMessageStatusBySourceMessageId(
    String sourceMessageId,
    String status,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'sms_messages',
      columns: ['id'],
      where: 'source_message_id = ?',
      whereArgs: [sourceMessageId],
    );
    final updated = await db.update(
      'sms_messages',
      {'status': status, 'sent_at': DateTime.now().toIso8601String()},
      where: 'source_message_id = ?',
      whereArgs: [sourceMessageId],
    );
    if (updated > 0) {
      for (final row in rows) {
        final id = (row['id'] as num?)?.toInt();
        if (id != null) {
          await DatabaseHelper.instance.enqueueSupabaseSyncUpsert(
            tableName: 'sms_messages',
            rowId: id,
          );
        }
      }
    }
    return updated;
  }

  Future<int> deleteSmsMessage(int id) async {
    final db = await DatabaseHelper.instance.database;
    final deleted = await db.delete(
      'sms_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (deleted > 0) {
      await DatabaseHelper.instance.enqueueSupabaseSyncDeletion(
        tableName: 'sms_messages',
        rowId: id,
      );
    }
    return deleted;
  }

  Future<int> deleteSmsConversation(String phoneNumber) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    final rows = await db.query(
      'sms_messages',
      columns: ['id'],
      where: 'phone_number = ?',
      whereArgs: [normalizedPhone],
    );
    final deleted = await db.delete(
      'sms_messages',
      where: 'phone_number = ?',
      whereArgs: [normalizedPhone],
    );
    if (deleted > 0) {
      for (final row in rows) {
        final id = (row['id'] as num?)?.toInt();
        if (id != null) {
          await DatabaseHelper.instance.enqueueSupabaseSyncDeletion(
            tableName: 'sms_messages',
            rowId: id,
          );
        }
      }
    }
    return deleted;
  }
}
