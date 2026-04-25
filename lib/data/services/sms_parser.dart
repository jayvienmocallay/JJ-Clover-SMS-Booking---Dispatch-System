// Task 004 — SMS Parser: regex-based command extraction from incoming messages
// Task 007 — Updated DELIVER regex to capture gallon type (NEW/OLD)
// Task 015 — Added zero quantity validation
/// All recognized SMS command types that the system can process.
/// Commands are matched via regex in priority order (first match wins).
enum SmsCommand { deliver, drop, yes, status, unknown }

/// Holds the parsed result of an incoming SMS message.
///
/// After regex matching, this object contains the identified command type
/// along with any extracted parameters (quantity, gallon type, address).
class ParsedSms {
  /// The identified command type from the SMS
  final SmsCommand command;

  /// Number of gallons requested (extracted from DELIVER/DROP commands)
  final int? quantity;

  /// Gallon classification: 'new' for household, 'old' for store use.
  /// Extracted from optional keyword in DELIVER command (e.g., "DELIVER 3 NEW")
  final String? gallonType;

  /// Optional delivery address (only from DELIVER commands with address text)
  final String? address;

  /// The original unmodified SMS message text
  final String rawMessage;

  ParsedSms({
    required this.command,
    this.quantity,
    this.gallonType,
    this.address,
    required this.rawMessage,
  });
}

/// Parses incoming SMS messages into structured command objects.
///
/// Every inbound SMS is normalized (trimmed, uppercased) then matched
/// against regex patterns in priority order. The first match wins;
/// unrecognized messages fall to the catch-all [SmsCommand.unknown] handler.
///
/// Supported formats:
/// - `DELIVER [qty]` — e.g., "DELIVER 5"
/// - `DELIVER [qty] NEW|OLD` — e.g., "DELIVER 3 NEW"
/// - `DELIVER [qty] [address]` — e.g., "DELIVER 2 Purok 4"
/// - `DELIVER [qty] NEW|OLD [address]` — e.g., "DELIVER 3 NEW Purok 4"
/// - `DROP [qty]` — e.g., "DROP 2"
/// - `YES` — confirms a pre-booking offer
/// - `STATUS` — returns current system mode
class SmsParser {
  /// Matches: DELIVER [qty] [optional: NEW|OLD] [optional: address]
  /// Group 1 = quantity (required digits)
  /// Group 2 = gallon type (optional: NEW or OLD)
  /// Group 3 = address (optional: remaining text after gallon type)
  static final RegExp _deliverRegex = RegExp(
    r'^DELIVER\s+(\d+)(?:\s+(NEW|OLD))?(?:\s+(.+))?$',
  );

  /// Matches: DROP [qty]
  /// Group 1 = quantity (required digits)
  static final RegExp _dropRegex = RegExp(r'^DROP\s+(\d+)$');

  /// Matches: YES (exact, no extra text)
  static final RegExp _yesRegex = RegExp(r'^YES$');

  /// Matches: STATUS (exact, no extra text)
  static final RegExp _statusRegex = RegExp(r'^STATUS$');

  /// Parses an incoming SMS message into a [ParsedSms] command object.
  ///
  /// The message is first normalized (trimmed whitespace, converted to
  /// uppercase) to handle case-insensitive matching. Then regex patterns
  /// are tested in priority order: DELIVER > DROP > YES > STATUS > UNKNOWN.
  static ParsedSms parse(String message) {
    // Step 1: Normalize — remove leading/trailing whitespace, uppercase all text
    final normalized = message.trim().toUpperCase();

    // Step 2: Try DELIVER pattern first (highest priority command)
    final deliverMatch = _deliverRegex.firstMatch(normalized);
    if (deliverMatch != null) {
      // Extract the gallon type keyword if present (NEW or OLD)
      final gallonTypeRaw = deliverMatch.group(2);
      // Convert to lowercase for DB storage: 'NEW' -> 'new', 'OLD' -> 'old'
      final gallonType = gallonTypeRaw?.toLowerCase();

      return ParsedSms(
        command: SmsCommand.deliver,
        quantity: int.tryParse(deliverMatch.group(1) ?? ''),
        gallonType: gallonType,
        address: deliverMatch.group(3),
        rawMessage: message,
      );
    }

    // Step 3: Try DROP pattern (walk-in/drop-off at station)
    final dropMatch = _dropRegex.firstMatch(normalized);
    if (dropMatch != null) {
      return ParsedSms(
        command: SmsCommand.drop,
        quantity: int.tryParse(dropMatch.group(1) ?? ''),
        rawMessage: message,
      );
    }

    // Step 4: Try YES pattern (pre-book confirmation)
    final yesMatch = _yesRegex.firstMatch(normalized);
    if (yesMatch != null) {
      return ParsedSms(command: SmsCommand.yes, rawMessage: message);
    }

    // Step 5: Try STATUS pattern (system mode inquiry)
    final statusMatch = _statusRegex.firstMatch(normalized);
    if (statusMatch != null) {
      return ParsedSms(command: SmsCommand.status, rawMessage: message);
    }

    // Step 6: No pattern matched — return unknown command
    return ParsedSms(command: SmsCommand.unknown, rawMessage: message);
  }

  static ParsedSms? tryParseDeliverOnly(String message) {
    final normalized = message.trim().toUpperCase();
    final deliverMatch = _deliverRegex.firstMatch(normalized);
    if (deliverMatch != null) {
      final qty = int.tryParse(deliverMatch.group(1) ?? '');
      if (qty == null || qty <= 0) return null;
      final gallonTypeRaw = deliverMatch.group(2);
      final gallonType = gallonTypeRaw?.toLowerCase();
      return ParsedSms(
        command: SmsCommand.deliver,
        quantity: qty,
        gallonType: gallonType,
        address: deliverMatch.group(3),
        rawMessage: message,
      );
    }
    final dropMatch = _dropRegex.firstMatch(normalized);
    if (dropMatch != null) {
      final qty = int.tryParse(dropMatch.group(1) ?? '');
      if (qty == null || qty <= 0) return null;
      return ParsedSms(
        command: SmsCommand.drop,
        quantity: qty,
        rawMessage: message,
      );
    }
    return null;
  }

  /// Returns the help message sent when an unrecognized command is received.
  static String getUnknownCommandReply() {
    return 'Invalid. Use DELIVER [qty] or DROP [qty] where qty is 1 or more.';
  }
}
