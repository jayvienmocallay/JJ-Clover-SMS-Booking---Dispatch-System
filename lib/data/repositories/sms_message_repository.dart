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
    return db.update(
      'sms_messages',
      {
        'status': status,
        'sent_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSmsMessage(int id) async {
    final db = await DatabaseHelper.instance.database;
    return db.delete('sms_messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSmsConversation(String phoneNumber) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    return db.delete(
      'sms_messages',
      where: 'phone_number = ?',
      whereArgs: [normalizedPhone],
    );
  }
}
