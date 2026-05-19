import '../../database_helper.dart';

typedef IncomingSmsReceiptClaimResult = ({bool claimed, bool isDuplicate});

class IncomingSmsReceiptRepository {
  Future<IncomingSmsReceiptClaimResult> claim({
    required String messageId,
    required String phoneNumber,
    required String message,
    int? smsTimestamp,
  }) {
    return DatabaseHelper.instance.claimIncomingSmsReceipt(
      messageId: messageId,
      phoneNumber: phoneNumber,
      message: message,
      smsTimestamp: smsTimestamp,
    );
  }

  Future<void> complete(String messageId) {
    return DatabaseHelper.instance.completeIncomingSmsReceipt(messageId);
  }

  Future<void> fail(String messageId, Object error) {
    return DatabaseHelper.instance.failIncomingSmsReceipt(messageId, error);
  }

  Future<Map<String, dynamic>?> getByMessageId(String messageId) {
    return DatabaseHelper.instance.getIncomingSmsReceipt(messageId);
  }

  Future<List<Map<String, dynamic>>> getRetryable({
    required int maxAttempts,
    required Duration staleAfter,
    int limit = 20,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final staleBefore = DateTime.now().subtract(staleAfter).toIso8601String();
    return db.query(
      'incoming_sms_receipts',
      where: '''
        (status = ? AND attempts < ?)
        OR (status = ? AND attempts < ? AND claimed_at IS NOT NULL AND claimed_at < ?)
      ''',
      whereArgs: [
        'failed',
        maxAttempts,
        'processing',
        maxAttempts,
        staleBefore,
      ],
      orderBy: 'updated_at ASC',
      limit: limit,
    );
  }

  Future<int> failExhaustedStaleProcessing({
    required int maxAttempts,
    required Duration staleAfter,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final staleBefore = DateTime.now().subtract(staleAfter).toIso8601String();
    return db.update(
      'incoming_sms_receipts',
      {
        'status': 'failed',
        'updated_at': DateTime.now().toIso8601String(),
        'last_error': 'SMS processing exceeded $maxAttempts attempts.',
      },
      where: '''
        status = ?
        AND attempts >= ?
        AND claimed_at IS NOT NULL
        AND claimed_at < ?
      ''',
      whereArgs: ['processing', maxAttempts, staleBefore],
    );
  }
}
