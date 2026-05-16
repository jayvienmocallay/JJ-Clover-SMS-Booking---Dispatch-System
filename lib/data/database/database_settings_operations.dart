part of 'database_helper.dart';

extension DatabaseSettingsOperations on DatabaseHelper {
  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
  }

  // --- First-contact notification tracking ---
  // Tracks whether a phone number has received the automated welcome message.

  /// Returns true if this phone number has already been notified.
  Future<bool> isFirstContactNotified(String phoneNumber) async {
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    final key = 'first_contact_$normalizedPhone';
    final value = await getSetting(key);
    return value != null;
  }

  /// Marks this phone number as having been notified.
  Future<void> markFirstContactNotified(String phoneNumber) async {
    final normalizedPhone = PhoneNumberUtils.normalize(phoneNumber);
    final key = 'first_contact_$normalizedPhone';
    await setSetting(key, DateTime.now().toIso8601String());
  }

  static const String readMessageIdsKey = 'read_message_ids';
  static const String preBookPendingKey = 'pre_book_pending';
  static const String cutoffHourKey = 'cutoff_hour';
  static const String cutoffMinuteKey = 'cutoff_minute';

  Future<Set<int>> getReadMessageIds() async {
    final value = await getSetting(readMessageIdsKey);
    if (value == null || value.isEmpty) return {};
    try {
      return value
          .split(',')
          .where((s) => s.isNotEmpty)
          .map((s) => int.parse(s))
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> setReadMessageIds(Set<int> ids) async {
    await setSetting(readMessageIdsKey, ids.join(','));
  }

  Future<Map<String, Map<String, dynamic>>> getPreBookPending() async {
    final value = await getSetting(preBookPendingKey);
    if (value == null || value.isEmpty) return {};
    try {
      return _decodePreBookPendingJson(value);
    } on FormatException {
      final legacyPending = _decodeLegacyPreBookPending(value);
      if (legacyPending.isNotEmpty) {
        await setPreBookPending(legacyPending);
      }
      return legacyPending;
    } catch (_) {
      return {};
    }
  }

  Future<void> setPreBookPending(
    Map<String, Map<String, dynamic>> pending,
  ) async {
    final serialized = <String, Map<String, dynamic>>{};
    for (final entry in pending.entries) {
      final context = _coercePreBookPendingContext(entry.key, entry.value);
      if (context != null) {
        serialized[entry.key] = context;
      }
    }
    await setSetting(preBookPendingKey, jsonEncode(serialized));
  }

  Map<String, Map<String, dynamic>> _decodePreBookPendingJson(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) return {};

    final result = <String, Map<String, dynamic>>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      if (key is! String) continue;

      final context = _coercePreBookPendingContext(key, entry.value);
      if (context != null) {
        result[key] = context;
      }
    }
    return result;
  }

  Map<String, Map<String, dynamic>> _decodeLegacyPreBookPending(String value) {
    final result = <String, Map<String, dynamic>>{};
    final entries = value.split(RegExp(r'\|(?=\+?\d+~\d+~\d+~)'));

    for (final entry in entries) {
      final context = _decodeLegacyPreBookPendingEntry(entry);
      if (context != null) {
        result[context['phoneNumber'] as String] = context;
      }
    }
    return result;
  }

  Map<String, dynamic>? _decodeLegacyPreBookPendingEntry(String value) {
    if (value.isEmpty) return null;

    final parts = value.split('~');
    if (parts.length < 6) return null;

    final phoneNumber = parts[0];
    final customerId = int.tryParse(parts[1]);
    final quantity = int.tryParse(parts[2]);
    if (phoneNumber.isEmpty || customerId == null || quantity == null) {
      return null;
    }

    final timestamp = int.tryParse(parts.last);
    final deliveryDayIndex = timestamp == null
        ? parts.length - 1
        : parts.length - 2;
    if (deliveryDayIndex < 5) return null;

    final address = parts.sublist(4, deliveryDayIndex).join('~');
    final deliveryDay = parts[deliveryDayIndex];
    if (deliveryDay.isEmpty) return null;

    return {
      'customerId': customerId,
      'phoneNumber': phoneNumber,
      'quantity': quantity,
      'gallonType': parts[3].isEmpty ? null : parts[3],
      'address': address.isEmpty ? null : address,
      'deliveryDay': deliveryDay,
      'timestamp': timestamp ?? 0,
    };
  }

  Map<String, dynamic>? _coercePreBookPendingContext(
    String phoneKey,
    Object? value,
  ) {
    if (value is! Map) return null;

    final customerId = _asInt(value['customerId']);
    final quantity = _asInt(value['quantity']);
    final deliveryDay = _asNonEmptyString(value['deliveryDay']);
    if (customerId == null || quantity == null || deliveryDay == null) {
      return null;
    }

    return {
      'customerId': customerId,
      'phoneNumber': _asNonEmptyString(value['phoneNumber']) ?? phoneKey,
      'quantity': quantity,
      'gallonType': _asNonEmptyString(value['gallonType']),
      'address': _asNonEmptyString(value['address']),
      'deliveryDay': deliveryDay,
      'scheduledFor': _asNonEmptyString(value['scheduledFor']),
      'pendingOrderId': _asInt(value['pendingOrderId']),
      'timestamp': _asInt(value['timestamp']) ?? 0,
    };
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  String? _asNonEmptyString(Object? value) {
    if (value == null) return null;
    final stringValue = value.toString();
    return stringValue.isEmpty ? null : stringValue;
  }

  Future<int> getCutoffHour() async {
    final value = await getSetting(cutoffHourKey);
    return int.tryParse(value ?? '') ?? 7;
  }

  Future<int> getCutoffMinute() async {
    final value = await getSetting(cutoffMinuteKey);
    return int.tryParse(value ?? '') ?? 0;
  }

  Future<void> setCutoffTime(int hour, int minute) async {
    await setSetting(cutoffHourKey, hour.toString());
    await setSetting(cutoffMinuteKey, minute.toString());
  }
}
