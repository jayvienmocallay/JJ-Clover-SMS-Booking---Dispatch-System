import '../database/retention_policy_dao.dart';

class RetentionPolicyRepository {
  RetentionPolicyRepository({RetentionPolicyDao? dao})
    : _dao = dao ?? RetentionPolicyDao();

  final RetentionPolicyDao _dao;

  Future<int> applyDefaultPolicy({DateTime? now}) {
    return _dao.apply(now: now);
  }
}
