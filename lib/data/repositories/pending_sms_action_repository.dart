import '../../database_helper.dart';

class PendingSmsActionRepository {
  Future<Map<String, dynamic>?> get(
    String phoneNumber, {
    Duration maxAge = const Duration(minutes: 30),
  }) {
    return DatabaseHelper.instance.getPendingSmsAction(
      phoneNumber,
      maxAge: maxAge,
    );
  }

  Future<void> upsert({
    required String phoneNumber,
    required String action,
    required String step,
    String? name,
    int? barangayId,
    String? address,
    String? consentVersion,
    String? consentGivenAt,
  }) {
    return DatabaseHelper.instance.upsertPendingSmsAction(
      phoneNumber: phoneNumber,
      action: action,
      step: step,
      name: name,
      barangayId: barangayId,
      address: address,
      consentVersion: consentVersion,
      consentGivenAt: consentGivenAt,
    );
  }

  Future<void> delete(String phoneNumber) {
    return DatabaseHelper.instance.deletePendingSmsAction(phoneNumber);
  }

  Future<void> prune({Duration maxAge = const Duration(minutes: 30)}) {
    return DatabaseHelper.instance.prunePendingSmsActions(maxAge: maxAge);
  }
}
