enum SmsCommand { deliver, drop, yes, status, unknown }

class ParsedSms {
  final SmsCommand command;
  final int? quantity;
  final String? address;
  final String rawMessage;

  ParsedSms({
    required this.command,
    this.quantity,
    this.address,
    required this.rawMessage,
  });
}

class SmsParser {
  static final RegExp _deliverRegex = RegExp(r'^DELIVER\s+(\d+)(?:\s+(.+))?$');
  static final RegExp _dropRegex = RegExp(r'^DROP\s+(\d+)$');
  static final RegExp _yesRegex = RegExp(r'^YES$');
  static final RegExp _statusRegex = RegExp(r'^STATUS$');

  static ParsedSms parse(String message) {
    final normalized = message.trim().toUpperCase();

    final deliverMatch = _deliverRegex.firstMatch(normalized);
    if (deliverMatch != null) {
      return ParsedSms(
        command: SmsCommand.deliver,
        quantity: int.tryParse(deliverMatch.group(1) ?? ''),
        address: deliverMatch.group(2),
        rawMessage: message,
      );
    }

    final dropMatch = _dropRegex.firstMatch(normalized);
    if (dropMatch != null) {
      return ParsedSms(
        command: SmsCommand.drop,
        quantity: int.tryParse(dropMatch.group(1) ?? ''),
        rawMessage: message,
      );
    }

    final yesMatch = _yesRegex.firstMatch(normalized);
    if (yesMatch != null) {
      return ParsedSms(command: SmsCommand.yes, rawMessage: message);
    }

    final statusMatch = _statusRegex.firstMatch(normalized);
    if (statusMatch != null) {
      return ParsedSms(command: SmsCommand.status, rawMessage: message);
    }

    return ParsedSms(command: SmsCommand.unknown, rawMessage: message);
  }

  static String getUnknownCommandReply() {
    return 'Unrecognized command. Use DELIVER [qty] or DROP [qty].';
  }
}
