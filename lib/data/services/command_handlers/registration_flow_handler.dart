import 'package:flutter/foundation.dart';
import '../../../core/utils/phone_number_utils.dart';
import '../../models/customer_model.dart';
import '../../repositories/barangay_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/pending_sms_action_repository.dart';
import '../app_event_bus.dart';
import '../sms_parser.dart';
import '../sms_registration_copy.dart';
import '../supabase_sync_service.dart';
import 'sms_handler_utils.dart';

/// Handles RA 10173 privacy commands and the single-step SMS registration
/// format: REGISTER [name], [barangay], [address].
///
/// Returns `true` if the message was fully handled so the caller can skip
/// the normal command dispatch (DELIVER / DROP / YES / STATUS).
class RegistrationFlowHandler {
  final _barangays = BarangayRepository();
  final _customers = CustomerRepository();
  final _pendingActions = PendingSmsActionRepository();

  Future<bool> handle({
    required String sender,
    required ParsedSms parsed,
    required String sourceMessageId,
  }) async {
    final normalizedSender = PhoneNumberUtils.normalize(sender);
    final pending = await _pendingActions.get(
      normalizedSender,
      maxAge: SmsRegistrationCopy.pendingActionTtl,
    );
    final customerData = await _customers.getCustomerByPhone(normalizedSender);

    // DROP is intentionally allowed for unregistered walk-in customers and
    // must not be trapped by an unfinished registration flow.
    if (parsed.command == SmsCommand.drop) {
      return false;
    }

    // --- Right to access (MYDATA) ---
    if (parsed.command == SmsCommand.myData) {
      if (customerData == null) {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.noDataOnFile,

          sourceMessageId: sourceMessageId,
        );
        return true;
      }
      final joined = await _customers.getCustomerWithBarangayByPhone(
        normalizedSender,
      );
      final c = joined != null
          ? Customer.fromMap(joined)
          : Customer.fromSimple(customerData);
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.myData(
          name: c.name,
          phone: c.contactNumber,
          barangay: c.barangay,
          address: c.address,
        ),

        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    // --- Right to erasure / right to object - request phase ---
    if (parsed.command == SmsCommand.deleteData ||
        parsed.command == SmsCommand.optOut) {
      if (customerData == null && pending == null) {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.noDataOnFile,

          sourceMessageId: sourceMessageId,
        );
        return true;
      }
      await _pendingActions.upsert(
        phoneNumber: normalizedSender,
        action: 'delete',
        step: 'awaiting_confirm',
      );
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.deleteWarning,

        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    // --- Right to erasure - confirmation phase ---
    if (parsed.command == SmsCommand.confirmDelete) {
      if (pending == null || pending['action'] != 'delete') {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.confirmDeleteWithoutRequest,

          sourceMessageId: sourceMessageId,
        );
        return true;
      }
      await _customers.deleteCustomerByPhone(normalizedSender);
      await _pendingActions.delete(normalizedSender);
      try {
        await SupabaseSyncService.instance.deleteCustomerFromSupabase(
          normalizedSender,
        );
      } catch (e) {
        debugPrint('Supabase erasure failed (will retry on next sync): $e');
      }
      AppEventBus().notifyOrderReceived();
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.deleteComplete,

        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    // --- STOP cancels any in-flight delete request ---
    if (parsed.command == SmsCommand.stop && pending != null) {
      final action = pending['action'] as String?;
      await _pendingActions.delete(normalizedSender);
      if (action == 'delete') {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.deleteCancelled,

          sourceMessageId: sourceMessageId,
        );
        return true;
      }
    }

    // --- Anything other than CONFIRM DELETE / STOP during a pending delete
    //     counts as implicit cancellation per the warning message ---
    if (pending != null && pending['action'] == 'delete') {
      await _pendingActions.delete(normalizedSender);
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.deleteCancelled,

        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    if (pending != null && pending['action'] == 'register') {
      await _pendingActions.delete(normalizedSender);
    }

    // --- REGISTER [name], [barangay], [address] ---
    if (parsed.command == SmsCommand.register) {
      if (customerData != null) {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.alreadyRegistered,

          sourceMessageId: sourceMessageId,
        );
        return true;
      }

      final parts = _parseRegisterParts(parsed.name);
      if (parts == null) {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.registerMissingFields,

          sourceMessageId: sourceMessageId,
        );
        return true;
      }

      final matchedBarangay = _matchBarangayName(parts.barangay);
      if (matchedBarangay == null) {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.invalidBarangay(parts.barangay),

          sourceMessageId: sourceMessageId,
        );
        return true;
      }

      final barangay = await _barangays.getBarangayByName(matchedBarangay);
      if (barangay == null) {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.invalidBarangay(parts.barangay),

          sourceMessageId: sourceMessageId,
        );
        return true;
      }

      final consentGivenAt = DateTime.now().toIso8601String();
      final name = _toTitleCase(parts.name);
      final barangayName = _toTitleCase(matchedBarangay);
      final address = parts.address.trim();

      try {
        await _customers.insertCustomer({
          'name': name,
          'contact_number': normalizedSender,
          'address': address,
          'barangay_id': barangay['id'] as int,
          'consent_given': 1,
          'consent_timestamp': consentGivenAt,
          'consent_channel': SmsRegistrationCopy.channelSms,
          'consent_version': SmsRegistrationCopy.consentVersion,
        });
      } on CustomerPhoneAlreadyExistsException {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.alreadyRegistered,

          sourceMessageId: sourceMessageId,
        );
        return true;
      }

      AppEventBus().notifyOrderReceived();
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.registrationComplete(
          name: name,
          barangay: barangayName,
          address: address,
        ),

        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    // --- Legacy registration commands without REGISTER ---
    if (parsed.command == SmsCommand.agree ||
        parsed.command == SmsCommand.barangay ||
        parsed.command == SmsCommand.address) {
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.registerWrongFormat,

        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    // --- Unregistered sender sending any command that requires a customer record ---
    if (customerData == null && _requiresRegisteredCustomer(parsed.command)) {
      await SmsHandlerUtils.saveUnrecognized(
        sender,
        parsed.rawMessage,
        'Unregistered',
        sourceMessageId: sourceMessageId,
        quantity: parsed.quantity ?? 0,
      );
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.unknownNumberPrompt,

        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    return false;
  }

  bool _requiresRegisteredCustomer(SmsCommand command) {
    switch (command) {
      case SmsCommand.deliver:
      case SmsCommand.yes:
      case SmsCommand.cancel:
      case SmsCommand.status:
      case SmsCommand.unknown:
        return true;
      case SmsCommand.drop:
      case SmsCommand.register:
      case SmsCommand.agree:
      case SmsCommand.stop:
      case SmsCommand.barangay:
      case SmsCommand.address:
      case SmsCommand.myData:
      case SmsCommand.deleteData:
      case SmsCommand.confirmDelete:
      case SmsCommand.optOut:
        return false;
    }
  }
}

class _RegisterParts {
  final String name;
  final String barangay;
  final String address;

  const _RegisterParts({
    required this.name,
    required this.barangay,
    required this.address,
  });
}

extension on RegistrationFlowHandler {
  _RegisterParts? _parseRegisterParts(String? payload) {
    final raw = (payload ?? '').trim();
    if (raw.isEmpty) return null;
    final parts = raw.split(',');
    if (parts.length < 3) return null;
    final name = parts[0].trim();
    final barangay = parts[1].trim();
    final address = parts.sublist(2).join(',').trim();
    if (name.isEmpty || barangay.isEmpty || address.isEmpty) return null;
    return _RegisterParts(name: name, barangay: barangay, address: address);
  }

  String? _matchBarangayName(String input) {
    final inputKey = _normalizeBarangayKey(input);
    if (inputKey.isEmpty) return null;

    String? exactMatch;
    final candidates = <String>[];
    for (final name in SmsRegistrationCopy.validBarangays) {
      final key = _normalizeBarangayKey(name);
      if (key == inputKey) {
        exactMatch = name;
        break;
      }
      if (key.startsWith(inputKey) || inputKey.startsWith(key)) {
        candidates.add(name);
      }
    }

    if (exactMatch != null) return exactMatch;
    if (candidates.length == 1) return candidates.first;
    return null;
  }

  String _normalizeBarangayKey(String value) {
    final lowered = value
        .toLowerCase()
        .replaceAll('\u00F1', 'n')
        .replaceAll('\u00D1', 'n');
    return lowered.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _toTitleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final words = trimmed.split(RegExp(r'\s+'));
    return words
        .map((word) {
          final parts = word.split('-');
          final cased = parts
              .map((part) {
                if (part.isEmpty) return part;
                final head = part[0].toUpperCase();
                final tail = part.substring(1).toLowerCase();
                return '$head$tail';
              })
              .join('-');
          return cased;
        })
        .join(' ');
  }
}
