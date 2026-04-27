// Task 009 — Unit tests for SmsParser (all 5 commands + edge cases)
// Task 009 — SMS regex accuracy with real-world message variations
import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/services/sms_parser.dart';

void main() {
  group('SmsParser — DELIVER command', () {
    test('parses basic DELIVER with quantity only', () {
      final result = SmsParser.parse('DELIVER 5');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 5);
      expect(result.gallonType, isNull);
      expect(result.address, isNull);
    });

    test('parses DELIVER with gallon type NEW', () {
      final result = SmsParser.parse('DELIVER 3 NEW');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 3);
      expect(result.gallonType, 'new');
      expect(result.address, isNull);
    });

    test('parses DELIVER with gallon type OLD', () {
      final result = SmsParser.parse('DELIVER 2 OLD');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 2);
      expect(result.gallonType, 'old');
      expect(result.address, isNull);
    });

    test('parses DELIVER with address only (no gallon type)', () {
      final result = SmsParser.parse('DELIVER 4 Purok 3 near chapel');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 4);
      expect(result.gallonType, isNull);
      expect(result.address, 'Purok 3 near chapel');
    });

    test('parses DELIVER with gallon type AND address', () {
      final result = SmsParser.parse('DELIVER 3 NEW Purok 4');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 3);
      expect(result.gallonType, 'new');
      expect(result.address, 'Purok 4');
    });

    // Task 009 — Real-world variations
    test('handles lowercase deliver', () {
      final result = SmsParser.parse('deliver 5');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 5);
    });

    test('handles mixed case deliver', () {
      final result = SmsParser.parse('Deliver 3 New');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 3);
      expect(result.gallonType, 'new');
    });

    test('handles extra whitespace', () {
      final result = SmsParser.parse('  DELIVER  5  ');
      // trim() handles leading/trailing, but internal double spaces
      // may not match the regex — this verifies the behavior
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 5);
    });

    test('rejects quantity above maximum', () {
      final result = SmsParser.parse('DELIVER 100');
      expect(result.command, SmsCommand.unknown);
    });

    test('rejects DELIVER without quantity', () {
      final result = SmsParser.parse('DELIVER');
      // No quantity group → doesn't match DELIVER regex → falls to unknown
      expect(result.command, SmsCommand.unknown);
    });

    test('preserves raw message', () {
      final result = SmsParser.parse('deliver 5');
      expect(result.rawMessage, 'deliver 5');
    });
  });

  group('SmsParser — DROP command', () {
    test('parses basic DROP with quantity', () {
      final result = SmsParser.parse('DROP 2');
      expect(result.command, SmsCommand.drop);
      expect(result.quantity, 2);
    });

    test('handles lowercase drop', () {
      final result = SmsParser.parse('drop 3');
      expect(result.command, SmsCommand.drop);
      expect(result.quantity, 3);
    });

    test('rejects DROP without quantity', () {
      final result = SmsParser.parse('DROP');
      expect(result.command, SmsCommand.unknown);
    });

    test('rejects DROP with extra text', () {
      // DROP regex requires exact match: DROP + digits only
      final result = SmsParser.parse('DROP 2 extra text');
      expect(result.command, SmsCommand.unknown);
    });
  });

  group('SmsParser — YES command', () {
    test('parses exact YES', () {
      final result = SmsParser.parse('YES');
      expect(result.command, SmsCommand.yes);
    });

    test('handles lowercase yes', () {
      final result = SmsParser.parse('yes');
      expect(result.command, SmsCommand.yes);
    });

    test('handles mixed case Yes', () {
      final result = SmsParser.parse('Yes');
      expect(result.command, SmsCommand.yes);
    });

    test('rejects YES with extra text', () {
      final result = SmsParser.parse('YES please');
      expect(result.command, SmsCommand.unknown);
    });
  });

  group('SmsParser — STATUS command', () {
    test('parses exact STATUS', () {
      final result = SmsParser.parse('STATUS');
      expect(result.command, SmsCommand.status);
    });

    test('handles lowercase status', () {
      final result = SmsParser.parse('status');
      expect(result.command, SmsCommand.status);
    });

    test('rejects STATUS with extra text', () {
      final result = SmsParser.parse('STATUS check');
      expect(result.command, SmsCommand.unknown);
    });
  });

  group('SmsParser — UNKNOWN command', () {
    test('returns unknown for empty message', () {
      final result = SmsParser.parse('');
      expect(result.command, SmsCommand.unknown);
    });

    test('returns unknown for random text', () {
      final result = SmsParser.parse('Hello, when is my delivery?');
      expect(result.command, SmsCommand.unknown);
    });

    test('returns unknown for partial commands', () {
      final result = SmsParser.parse('DEL 5');
      expect(result.command, SmsCommand.unknown);
    });

    test('returns unknown for just a number', () {
      final result = SmsParser.parse('5');
      expect(result.command, SmsCommand.unknown);
    });

    test('getUnknownCommandReply returns help text', () {
      final reply = SmsParser.getUnknownCommandReply();
      expect(reply, contains('DELIVER'));
      expect(reply, contains('DROP'));
    });
  });

  // Task 009 — Real-world SMS edge cases
  group('SmsParser — Real-world edge cases', () {
    test('handles message with newlines', () {
      final result = SmsParser.parse('DELIVER 5\n');
      // trim() should handle trailing newline
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 5);
    });

    test('rejects zero quantity', () {
      final result = SmsParser.parse('DELIVER 0');
      expect(result.command, SmsCommand.unknown);
    });

    test('handles whitespace-only message', () {
      final result = SmsParser.parse('   ');
      expect(result.command, SmsCommand.unknown);
    });
  });
}
