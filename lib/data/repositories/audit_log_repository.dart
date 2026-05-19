import '../database/audit_log_dao.dart';

class AuditLogRepository {
  AuditLogRepository({AuditLogDao? dao}) : _dao = dao ?? AuditLogDao();

  final AuditLogDao _dao;

  Future<int> record({
    required String action,
    required String entityType,
    String? entityId,
    String? phoneNumber,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return _dao.insert(
      action: action,
      entityType: entityType,
      entityId: entityId,
      phoneNumber: phoneNumber,
      metadata: metadata,
      createdAt: createdAt,
    );
  }

  Future<List<Map<String, dynamic>>> latest({int? limit}) {
    return _dao.latest(limit: limit);
  }
}
