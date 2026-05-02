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
}
