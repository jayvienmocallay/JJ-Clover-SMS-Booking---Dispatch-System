import 'package:flutter/foundation.dart';
import 'package:another_telephony/telephony.dart';
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

/// Handles all RA 10173 privacy commands and the multi-step SMS registration
/// state machine (REGISTER -> AGREE -> BARANGAY -> ADDRESS).
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
    Telephony? smsSender,
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
          smsSender: smsSender,
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
        smsSender: smsSender,
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
          smsSender: smsSender,
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
        smsSender: smsSender,
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
          smsSender: smsSender,
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
        smsSender: smsSender,
        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    // --- STOP cancels any in-flight flow ---
    if (parsed.command == SmsCommand.stop && pending != null) {
      final action = pending['action'] as String?;
      await _pendingActions.delete(normalizedSender);
      await SmsHandlerUtils.sendReply(
        sender,
        action == 'delete'
            ? SmsRegistrationCopy.deleteCancelled
            : SmsRegistrationCopy.registrationCancelled,
        smsSender: smsSender,
        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    // --- Anything other than CONFIRM DELETE / STOP during a pending delete
    //     counts as implicit cancellation per the warning message ---
    if (pending != null && pending['action'] == 'delete') {
      await _pendingActions.delete(normalizedSender);
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.deleteCancelled,
        smsSender: smsSender,
        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    // --- REGISTER kicks off (or restarts) the consent flow ---
    if (parsed.command == SmsCommand.register) {
      if (customerData != null) {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.alreadyRegistered,
          smsSender: smsSender,
          sourceMessageId: sourceMessageId,
        );
        return true;
      }
      final name = parsed.name?.trim();
      if (name == null || name.isEmpty) {
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.registerHelp,
          smsSender: smsSender,
          sourceMessageId: sourceMessageId,
        );
        return true;
      }
      await _pendingActions.upsert(
        phoneNumber: normalizedSender,
        action: 'register',
        step: 'awaiting_consent',
        name: name,
      );
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.registrationConsent(name: name),
        smsSender: smsSender,
        sourceMessageId: sourceMessageId,
      );
      return true;
    }

    // --- Continue an in-progress registration flow ---
    if (pending != null &&
        pending['action'] == 'register' &&
        customerData == null) {
      return await _continueRegistration(
        sender: sender,
        normalizedSender: normalizedSender,
        parsed: parsed,
        pending: pending,
        sourceMessageId: sourceMessageId,
        smsSender: smsSender,
      );
    }

    // --- AGREE / BARANGAY / ADDRESS without an active flow ---
    if (parsed.command == SmsCommand.agree ||
        parsed.command == SmsCommand.barangay ||
        parsed.command == SmsCommand.address) {
      await SmsHandlerUtils.sendReply(
        sender,
        SmsRegistrationCopy.noPendingRegistration,
        smsSender: smsSender,
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
        smsSender: smsSender,
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

  /// Drives per-step transitions for a registration flow already recorded in
  /// `pending_sms_actions`.
  Future<bool> _continueRegistration({
    required String sender,
    required String normalizedSender,
    required ParsedSms parsed,
    required Map<String, dynamic> pending,
    required String sourceMessageId,
    Telephony? smsSender,
  }) async {
    final step = pending['step'] as String;
    final pendingName = pending['name'] as String?;
    final pendingBarangayId = pending['barangay_id'] as int?;
    final pendingConsentVersion = pending['consent_version'] as String?;
    final pendingConsentGivenAt = pending['consent_given_at'] as String?;

    switch (step) {
      case 'awaiting_consent':
        if (parsed.command == SmsCommand.agree) {
          final consentGivenAt = DateTime.now().toIso8601String();
          await _pendingActions.upsert(
            phoneNumber: normalizedSender,
            action: 'register',
            step: 'awaiting_barangay',
            name: pendingName,
            consentVersion: SmsRegistrationCopy.consentVersion,
            consentGivenAt: consentGivenAt,
          );
          final barangays = await _barangays.getBarangays();
          final list = barangays.map((b) => b['name'] as String).join(', ');
          await SmsHandlerUtils.sendReply(
            sender,
            SmsRegistrationCopy.askBarangay(list),
            smsSender: smsSender,
            sourceMessageId: sourceMessageId,
          );
          return true;
        }
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.consentRequired,
          smsSender: smsSender,
          sourceMessageId: sourceMessageId,
        );
        return true;

      case 'awaiting_barangay':
        if (parsed.command == SmsCommand.barangay) {
          final input = parsed.barangayName?.trim() ?? '';
          if (input.isEmpty) {
            await SmsHandlerUtils.sendReply(
              sender,
              SmsRegistrationCopy.invalidBarangay,
              smsSender: smsSender,
              sourceMessageId: sourceMessageId,
            );
            return true;
          }
          final barangay = await _barangays.getBarangayByName(input);
          if (barangay == null) {
            await SmsHandlerUtils.sendReply(
              sender,
              SmsRegistrationCopy.invalidBarangay,
              smsSender: smsSender,
              sourceMessageId: sourceMessageId,
            );
            return true;
          }
          await _pendingActions.upsert(
            phoneNumber: normalizedSender,
            action: 'register',
            step: 'awaiting_address',
            name: pendingName,
            barangayId: barangay['id'] as int,
            consentVersion: pendingConsentVersion,
            consentGivenAt: pendingConsentGivenAt,
          );
          await SmsHandlerUtils.sendReply(
            sender,
            SmsRegistrationCopy.askAddress,
            smsSender: smsSender,
            sourceMessageId: sourceMessageId,
          );
          return true;
        }
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.barangayPromptReminder,
          smsSender: smsSender,
          sourceMessageId: sourceMessageId,
        );
        return true;

      case 'awaiting_address':
        if (parsed.command == SmsCommand.address) {
          final addr = parsed.address?.trim() ?? '';
          if (addr.isEmpty) {
            await SmsHandlerUtils.sendReply(
              sender,
              SmsRegistrationCopy.addressPromptReminder,
              smsSender: smsSender,
              sourceMessageId: sourceMessageId,
            );
            return true;
          }
          if (pendingBarangayId == null || pendingName == null) {
            await _pendingActions.delete(normalizedSender);
            await SmsHandlerUtils.sendReply(
              sender,
              SmsRegistrationCopy.registerHelp,
              smsSender: smsSender,
              sourceMessageId: sourceMessageId,
            );
            return true;
          }
          try {
            await _customers.insertCustomer({
              'name': pendingName,
              'contact_number': normalizedSender,
              'address': addr,
              'barangay_id': pendingBarangayId,
              'consent_given': 1,
              'consent_timestamp': pendingConsentGivenAt,
              'consent_channel': SmsRegistrationCopy.channelSms,
              'consent_version':
                  pendingConsentVersion ?? SmsRegistrationCopy.consentVersion,
            });
          } on CustomerPhoneAlreadyExistsException {
            await _pendingActions.delete(normalizedSender);
            await SmsHandlerUtils.sendReply(
              sender,
              SmsRegistrationCopy.alreadyRegistered,
              smsSender: smsSender,
              sourceMessageId: sourceMessageId,
            );
            return true;
          }
          final barangay = await _barangays.getBarangayById(pendingBarangayId);
          await _pendingActions.delete(normalizedSender);
          AppEventBus().notifyOrderReceived();
          await SmsHandlerUtils.sendReply(
            sender,
            SmsRegistrationCopy.registrationComplete(
              name: pendingName,
              barangay: barangay?['name'] as String? ?? '',
            ),
            smsSender: smsSender,
            sourceMessageId: sourceMessageId,
          );
          return true;
        }
        await SmsHandlerUtils.sendReply(
          sender,
          SmsRegistrationCopy.addressPromptReminder,
          smsSender: smsSender,
          sourceMessageId: sourceMessageId,
        );
        return true;
    }

    // Unknown step - clear the row and treat as fresh.
    await _pendingActions.delete(normalizedSender);
    return false;
  }
}
