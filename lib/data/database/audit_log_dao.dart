import 'database_helper.dart';

class AuditLogDao {
  AuditLogDao({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<int> insert({
    required String action,
    required String entityType,
    String? entityId,
    String? phoneNumber,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return _databaseHelper.insertAuditLog(
      action: action,
      entityType: entityType,
      entityId: entityId,
      phoneNumber: phoneNumber,
      metadata: metadata,
      createdAt: createdAt,
    );
  }

  Future<List<Map<String, dynamic>>> latest({int? limit}) {
    return _databaseHelper.getAuditLogs(limit: limit);
  }
}
