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
}
