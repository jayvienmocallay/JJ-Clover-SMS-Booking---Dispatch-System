import 'database_helper.dart';

class DeletionRetryQueueDao {
  DeletionRetryQueueDao({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<int> enqueueCustomerErasure({
    required String phoneNumber,
    Object? lastError,
    DateTime? nextAttemptAt,
  }) {
    return _databaseHelper.enqueueDeletionRetry(
      phoneNumber: phoneNumber,
      lastError: lastError,
      nextAttemptAt: nextAttemptAt,
    );
  }

  Future<List<Map<String, dynamic>>> due({DateTime? now, int limit = 20}) {
    return _databaseHelper.getDueDeletionRetries(now: now, limit: limit);
  }

  Future<void> markSucceeded(int id) {
    return _databaseHelper.markDeletionRetrySucceeded(id);
  }

  Future<void> markFailed(int id, Object error) {
    return _databaseHelper.markDeletionRetryFailed(id, error);
  }
}
