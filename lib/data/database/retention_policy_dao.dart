import 'database_helper.dart';

class RetentionPolicyDao {
  RetentionPolicyDao({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<int> apply({
    Duration smsRetention = const Duration(days: 90),
    Duration receiptRetention = const Duration(days: 30),
    Duration auditRetention = const Duration(days: 365),
    Duration deletionRetryRetention = const Duration(days: 30),
    DateTime? now,
  }) {
    return _databaseHelper.applyRetentionPolicy(
      smsRetention: smsRetention,
      receiptRetention: receiptRetention,
      auditRetention: auditRetention,
      deletionRetryRetention: deletionRetryRetention,
      now: now,
    );
  }
}
