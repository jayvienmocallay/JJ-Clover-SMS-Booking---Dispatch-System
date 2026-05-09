import 'package:flutter/foundation.dart';
import '../models/pre_book_context.dart';
import '../repositories/pre_book_repository.dart';

/// Manages the in-memory map of pending pre-book offers and persists it to the
/// database so offers survive process restarts.
class PreBookStore {
  final _pending = <String, PreBookContext>{};
  final _repository = PreBookRepository();

  PreBookContext? operator [](String phoneNumber) => _pending[phoneNumber];

  Future<void> put(String phoneNumber, PreBookContext ctx) async {
    _pending[phoneNumber] = ctx;
    await _persist();
  }

  Future<void> remove(String phoneNumber) async {
    _pending.remove(phoneNumber);
    await _persist();
  }

  /// Loads non-expired pre-book contexts from the database on startup.
  Future<void> loadFromDb() async {
    try {
      final raw = await _repository.getPending();
      final now = DateTime.now();
      for (final entry in raw.entries) {
        final v = entry.value;
        final timestamp = v['timestamp'] as int? ?? 0;
        final createdAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (now.difference(createdAt).inHours <=
            PreBookContext.expirationHours) {
          _pending[entry.key] = PreBookContext(
            customerId: v['customerId'] as int,
            phoneNumber: v['phoneNumber'] as String,
            quantity: v['quantity'] as int,
            gallonType: v['gallonType'] as String?,
            address: v['address'] as String?,
            deliveryDay: v['deliveryDay'] as String,
            scheduledFor: DateTime.tryParse(v['scheduledFor'] as String? ?? '') ?? createdAt,
            createdAt: createdAt,
          );
        }
      }
      debugPrint('PreBookStore: loaded ${_pending.length} pending pre-books');
    } catch (e) {
      debugPrint('PreBookStore: failed to load from DB: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final data = <String, Map<String, dynamic>>{};
      for (final entry in _pending.entries) {
        final c = entry.value;
        data[entry.key] = {
          'customerId': c.customerId,
          'phoneNumber': c.phoneNumber,
          'quantity': c.quantity,
          'gallonType': c.gallonType,
          'address': c.address,
          'deliveryDay': c.deliveryDay,
          'scheduledFor': c.scheduledFor.toIso8601String(),
          'timestamp': c.createdAt.millisecondsSinceEpoch,
        };
      }
      await _repository.setPending(data);
    } catch (e) {
      debugPrint('PreBookStore: failed to persist: $e');
    }
  }
}
