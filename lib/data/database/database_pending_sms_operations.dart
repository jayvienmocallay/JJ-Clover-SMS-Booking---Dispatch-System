part of 'database_helper.dart';

extension DatabasePendingSmsOperations on DatabaseHelper {
  Future<Map<String, dynamic>?> getPendingSmsAction(
    String phoneNumber, {
    Duration maxAge = const Duration(minutes: 30),
  }) async {
    final db = await DatabaseHelper.instance.database;
    final normalized = PhoneNumberUtils.normalize(phoneNumber);
    await prunePendingSmsActions(maxAge: maxAge);
    final rows = await db.query(
      'pending_sms_actions',
      where: 'phone_number = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Inserts or replaces the pending SMS action for [phoneNumber].
  /// `created_at` is preserved if the row already exists; `updated_at`
  /// always advances so prune sweeps can drop stale flows.
  Future<void> upsertPendingSmsAction({
    required String phoneNumber,
    required String action,
    required String step,
    String? name,
    int? barangayId,
    String? address,
    String? consentVersion,
    String? consentGivenAt,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final normalized = PhoneNumberUtils.normalize(phoneNumber);
    final nowIso = DateTime.now().toIso8601String();

    final existing = await db.query(
      'pending_sms_actions',
      columns: ['created_at'],
      where: 'phone_number = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    final createdAt = existing.isNotEmpty
        ? (existing.first['created_at'] as String)
        : nowIso;

    await db.insert('pending_sms_actions', {
      'phone_number': normalized,
      'action': action,
      'step': step,
      'name': name,
      'barangay_id': barangayId,
      'address': address,
      'consent_version': consentVersion,
      'consent_given_at': consentGivenAt,
      'created_at': createdAt,
      'updated_at': nowIso,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Removes the pending action for [phoneNumber] (no-op if none).
  Future<void> deletePendingSmsAction(String phoneNumber) async {
    final db = await DatabaseHelper.instance.database;
    final normalized = PhoneNumberUtils.normalize(phoneNumber);
    await db.delete(
      'pending_sms_actions',
      where: 'phone_number = ?',
      whereArgs: [normalized],
    );
  }

  /// Drops pending action rows whose `updated_at` is older than [maxAge].
  /// Called automatically by [getPendingSmsAction]; safe to invoke directly.
  Future<void> prunePendingSmsActions({
    Duration maxAge = const Duration(minutes: 30),
  }) async {
    final db = await DatabaseHelper.instance.database;
    final cutoff = DateTime.now().subtract(maxAge).toIso8601String();
    await db.delete(
      'pending_sms_actions',
      where: 'updated_at < ?',
      whereArgs: [cutoff],
    );
  }
}
