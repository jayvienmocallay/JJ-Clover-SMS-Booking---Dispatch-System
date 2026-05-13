import '../database/deletion_retry_queue_dao.dart';

class DeletionRetryQueueRepository {
  DeletionRetryQueueRepository({DeletionRetryQueueDao? dao})
    : _dao = dao ?? DeletionRetryQueueDao();

  final DeletionRetryQueueDao _dao;

  Future<int> enqueueCustomerErasure({
    required String phoneNumber,
    Object? lastError,
    DateTime? nextAttemptAt,
  }) {
    return _dao.enqueueCustomerErasure(
      phoneNumber: phoneNumber,
      lastError: lastError,
      nextAttemptAt: nextAttemptAt,
    );
  }

  Future<List<Map<String, dynamic>>> dueCustomerErasures({
    DateTime? now,
    int limit = 20,
  }) {
    return _dao.due(now: now, limit: limit);
  }

  Future<void> markSucceeded(int id) {
    return _dao.markSucceeded(id);
  }

  Future<void> markFailed(int id, Object error) {
    return _dao.markFailed(id, error);
  }
}
