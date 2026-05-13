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
      expect(result.address, isNull);
    });

    test('parses DELIVER with address only (no gallon type)', () {
      final result = SmsParser.parse('DELIVER 4 Purok 3 near chapel');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 4);
      expect(result.address, 'Purok 3 near chapel');
    });

    // Task 009 — Real-world variations
    test('handles lowercase deliver', () {
      final result = SmsParser.parse('deliver 5');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 5);
    });

    test('handles mixed case deliver', () {
      final result = SmsParser.parse('Deliver 3 Purok 4');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 3);
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

  group('SmsParser - CANCEL command', () {
    test('parses exact CANCEL', () {
      final result = SmsParser.parse('CANCEL');
      expect(result.command, SmsCommand.cancel);
    });

    test('handles lowercase cancel', () {
      final result = SmsParser.parse('cancel');
      expect(result.command, SmsCommand.cancel);
    });

    test('rejects CANCEL with extra text', () {
      final result = SmsParser.parse('CANCEL order');
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
      expect(reply, contains('CANCEL'));
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

    test('normalizes tabs, CRLF, NBSP, and repeated spaces', () {
      final result = SmsParser.parse('DELIVER\t\u00A0 5\r\nPurok   2');
      expect(result.command, SmsCommand.deliver);
      expect(result.quantity, 5);
      expect(result.address, 'Purok 2');
    });

    test('accepts command separators and trailing punctuation', () {
      final deliver = SmsParser.parse('DELIVER: 5,');
      final drop = SmsParser.parse('DROP - 2.');
      final cancel = SmsParser.parse('CANCEL!');
      final confirm = SmsParser.parse('CONFIRM-DELETE.');

      expect(deliver.command, SmsCommand.deliver);
      expect(deliver.quantity, 5);
      expect(drop.command, SmsCommand.drop);
      expect(drop.quantity, 2);
      expect(cancel.command, SmsCommand.cancel);
      expect(confirm.command, SmsCommand.confirmDelete);
    });

    test('preserves raw message while parsing normalized text', () {
      final raw = '  deliver:\t5.  ';
      final result = SmsParser.parse(raw);
      expect(result.command, SmsCommand.deliver);
      expect(result.rawMessage, raw);
    });

    test('does not accept aliases or natural-language orders', () {
      expect(SmsParser.parse('DEL 5').command, SmsCommand.unknown);
      expect(SmsParser.parse('D 5').command, SmsCommand.unknown);
      expect(
        SmsParser.parse('pa deliver 5 gallons tomorrow').command,
        SmsCommand.unknown,
      );
    });
  });
}
