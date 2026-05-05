// Task 004 — SMS Parser: regex-based command extraction from incoming messages
// Task 007 — Updated DELIVER regex to capture gallon type (NEW/OLD)
// Task 015 — Added zero quantity validation
// Task 020 — Added REGISTER/AGREE/STOP/BARANGAY/ADDRESS/MYDATA/DELETEDATA/
//            CONFIRM DELETE/OPTOUT for RA 10173 self-registration & data rights
import '../../core/constants/app_constants.dart';

/// All recognized SMS command types that the system can process.
/// Commands are matched via regex in priority order (first match wins).
enum SmsCommand {
  deliver,
  drop,
  yes,
  status,
  // Registration & data-rights flow (RA 10173).
  register,
  agree,
  stop,
  barangay,
  address,
  myData,
  deleteData,
  confirmDelete,
  optOut,
  unknown,
}

/// Holds the parsed result of an incoming SMS message.
///
/// After regex matching, this object contains the identified command type
/// along with any extracted parameters (quantity, gallon type, address,
/// registration name, barangay name).
class ParsedSms {
  final SmsCommand command;
  final int? quantity;
  final String? gallonType;
  final String? address;
  final String? name;
  final String? barangayName;
  final String rawMessage;

  ParsedSms({
    required this.command,
    this.quantity,
    this.gallonType,
    this.address,
    this.name,
    this.barangayName,
    required this.rawMessage,
  });
}

/// Parses incoming SMS messages into structured command objects.
///
/// Every inbound SMS is trimmed and matched case-insensitively against
/// regex patterns in priority order. The first match wins; unrecognized
/// messages fall to the catch-all [SmsCommand.unknown] handler.
///
/// Supported formats:
/// - `DELIVER [qty]` — e.g., "DELIVER 5"
/// - `DELIVER [qty] NEW|OLD` — e.g., "DELIVER 3 NEW"
/// - `DELIVER [qty] [address]` — e.g., "DELIVER 2 Purok 4"
/// - `DELIVER [qty] NEW|OLD [address]` — e.g., "DELIVER 3 NEW Purok 4"
/// - `DROP [qty]` — e.g., "DROP 2"
/// - `YES` — confirms a pre-booking offer
/// - `STATUS` — returns current system mode
/// - `REGISTER [name]` — starts self-registration (RA 10173 consent flow)
/// - `AGREE` / `STOP` — consent / cancel during registration
/// - `BARANGAY [name]` — provides barangay during registration
/// - `ADDRESS [text]` — provides delivery address during registration
/// - `MYDATA` — request data on file (RA 10173 right to access)
/// - `DELETEDATA` / `OPTOUT` — request deletion (RA 10173 right to erasure)
/// - `CONFIRM DELETE` — confirms a pending deletion request
class SmsParser {
  /// Matches: DELIVER [qty] [optional: NEW|OLD] [optional: address]
  /// Group 1 = quantity (required digits, max 4 digits for safety)
  /// Group 2 = gallon type (optional: NEW or OLD)
  /// Group 3 = address (optional: remaining text after gallon type)
  /// Uses [\s\S] instead of . to match newlines in multiline SMS
  static final RegExp _deliverRegex = RegExp(
    r'^DELIVER\s+(\d{1,4})(?:\s+(NEW|OLD))?(?:\s+([\s\S]+))?$',
    caseSensitive: false,
  );

  /// Matches: DROP [qty]
  /// Group 1 = quantity (required digits, max 4 digits for safety)
  static final RegExp _dropRegex = RegExp(r'^DROP\s+(\d{1,4})$', caseSensitive: false);

  /// Matches: YES (exact, no extra text)
  static final RegExp _yesRegex = RegExp(r'^YES$', caseSensitive: false);

  /// Matches: STATUS (exact, no extra text)
  static final RegExp _statusRegex = RegExp(r'^STATUS$', caseSensitive: false);

  /// Matches: REGISTER [name]. Group 1 = full name (rest of the message).
  static final RegExp _registerRegex = RegExp(
    r'^REGISTER\s+([\s\S]+)$',
    caseSensitive: false,
  );

  /// Matches: AGREE (exact, no extra text)
  static final RegExp _agreeRegex = RegExp(r'^AGREE$', caseSensitive: false);

  /// Matches: STOP (exact)
  static final RegExp _stopRegex = RegExp(r'^STOP$', caseSensitive: false);

  /// Matches: BARANGAY [name]. Group 1 = barangay name.
  static final RegExp _barangayRegex = RegExp(
    r'^BARANGAY\s+([\s\S]+)$',
    caseSensitive: false,
  );

  /// Matches: ADDRESS [text]. Group 1 = free-text address.
  static final RegExp _addressRegex = RegExp(
    r'^ADDRESS\s+([\s\S]+)$',
    caseSensitive: false,
  );

  /// Matches: MYDATA (exact)
  static final RegExp _myDataRegex = RegExp(r'^MYDATA$', caseSensitive: false);

  /// Matches: DELETEDATA (exact)
  static final RegExp _deleteDataRegex =
      RegExp(r'^DELETEDATA$', caseSensitive: false);

  /// Matches: CONFIRM DELETE (one or more spaces between the words)
  static final RegExp _confirmDeleteRegex =
      RegExp(r'^CONFIRM\s+DELETE$', caseSensitive: false);

  /// Matches: OPTOUT (exact). Equivalent to DELETEDATA per RA 10173 right to object.
  static final RegExp _optOutRegex = RegExp(r'^OPTOUT$', caseSensitive: false);

  static int? _parseValidQuantity(String? value) {
    final qty = int.tryParse(value ?? '');
    if (qty == null) return null;
    if (qty < AppConstants.minQuantity || qty > AppConstants.maxQuantity) {
      return null;
    }
    return qty;
  }

  static String? _cleanAddress(String? value) {
    return value?.trim();
  }

  /// Parses an incoming SMS message into a [ParsedSms] command object.
  ///
  /// The message is trimmed and matched case-insensitively against regex
  /// patterns in priority order:
  /// DELIVER > DROP > YES > STATUS >
  /// REGISTER > AGREE > STOP > BARANGAY > ADDRESS >
  /// MYDATA > DELETEDATA > CONFIRM DELETE > OPTOUT > UNKNOWN.
  static ParsedSms parse(String message) {
    final trimmed = message.trim();

    final deliverMatch = _deliverRegex.firstMatch(trimmed);
    if (deliverMatch != null) {
      final qty = _parseValidQuantity(deliverMatch.group(1));
      if (qty == null) {
        return ParsedSms(
          command: SmsCommand.unknown,
          rawMessage: message,
        );
      }
      final gallonTypeRaw = deliverMatch.group(2);
      final gallonType = gallonTypeRaw?.toLowerCase();

      return ParsedSms(
        command: SmsCommand.deliver,
        quantity: qty,
        gallonType: gallonType,
        address: _cleanAddress(deliverMatch.group(3)),
        rawMessage: message,
      );
    }

    final dropMatch = _dropRegex.firstMatch(trimmed);
    if (dropMatch != null) {
      final qty = _parseValidQuantity(dropMatch.group(1));
      if (qty == null) {
        return ParsedSms(
          command: SmsCommand.unknown,
          rawMessage: message,
        );
      }
      return ParsedSms(
        command: SmsCommand.drop,
        quantity: qty,
        rawMessage: message,
      );
    }

    if (_yesRegex.hasMatch(trimmed)) {
      return ParsedSms(command: SmsCommand.yes, rawMessage: message);
    }

    if (_statusRegex.hasMatch(trimmed)) {
      return ParsedSms(command: SmsCommand.status, rawMessage: message);
    }

    final registerMatch = _registerRegex.firstMatch(trimmed);
    if (registerMatch != null) {
      return ParsedSms(
        command: SmsCommand.register,
        name: registerMatch.group(1)?.trim(),
        rawMessage: message,
      );
    }

    if (_agreeRegex.hasMatch(trimmed)) {
      return ParsedSms(command: SmsCommand.agree, rawMessage: message);
    }

    if (_stopRegex.hasMatch(trimmed)) {
      return ParsedSms(command: SmsCommand.stop, rawMessage: message);
    }

    final barangayMatch = _barangayRegex.firstMatch(trimmed);
    if (barangayMatch != null) {
      return ParsedSms(
        command: SmsCommand.barangay,
        barangayName: barangayMatch.group(1)?.trim(),
        rawMessage: message,
      );
    }

    final addressMatch = _addressRegex.firstMatch(trimmed);
    if (addressMatch != null) {
      return ParsedSms(
        command: SmsCommand.address,
        address: _cleanAddress(addressMatch.group(1)),
        rawMessage: message,
      );
    }

    if (_myDataRegex.hasMatch(trimmed)) {
      return ParsedSms(command: SmsCommand.myData, rawMessage: message);
    }

    if (_deleteDataRegex.hasMatch(trimmed)) {
      return ParsedSms(command: SmsCommand.deleteData, rawMessage: message);
    }

    if (_confirmDeleteRegex.hasMatch(trimmed)) {
      return ParsedSms(command: SmsCommand.confirmDelete, rawMessage: message);
    }

    if (_optOutRegex.hasMatch(trimmed)) {
      return ParsedSms(command: SmsCommand.optOut, rawMessage: message);
    }

    return ParsedSms(command: SmsCommand.unknown, rawMessage: message);
  }

  /// Tries to parse only DELIVER or DROP commands.
  /// Returns null if message doesn't match either pattern.
  static ParsedSms? tryParseDeliverOrDrop(String message) {
    final trimmed = message.trim();

    final deliverMatch = _deliverRegex.firstMatch(trimmed);
    if (deliverMatch != null) {
      final qty = _parseValidQuantity(deliverMatch.group(1));
      if (qty == null) return null;
      final gallonTypeRaw = deliverMatch.group(2);
      final gallonType = gallonTypeRaw?.toLowerCase();
      return ParsedSms(
        command: SmsCommand.deliver,
        quantity: qty,
        gallonType: gallonType,
        address: _cleanAddress(deliverMatch.group(3)),
        rawMessage: message,
      );
    }

    final dropMatch = _dropRegex.firstMatch(trimmed);
    if (dropMatch != null) {
      final qty = _parseValidQuantity(dropMatch.group(1));
      if (qty == null) return null;
      return ParsedSms(
        command: SmsCommand.drop,
        quantity: qty,
        rawMessage: message,
      );
    }
    return null;
  }

  /// Returns the help message sent when an unrecognized command is received
  /// from a registered customer.
  static String getUnknownCommandReply() {
    return 'Invalid. Use DELIVER [${AppConstants.minQuantity}-${AppConstants.maxQuantity}] or DROP [${AppConstants.minQuantity}-${AppConstants.maxQuantity}]. '
        'Text MYDATA / DELETEDATA for privacy rights.';
  }
}
