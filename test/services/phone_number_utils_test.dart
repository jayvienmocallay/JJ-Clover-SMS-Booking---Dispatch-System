import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/core/utils/phone_number_utils.dart';

void main() {
  group('PhoneNumberUtils.normalize', () {
    test('keeps local mobile numbers in 09 format', () {
      expect(PhoneNumberUtils.normalize('09171234567'), '09171234567');
    });

    test('converts international +63 format to 09 format', () {
      expect(PhoneNumberUtils.normalize('+639171234567'), '09171234567');
    });

    test('converts bare 63 format to 09 format', () {
      expect(PhoneNumberUtils.normalize('639171234567'), '09171234567');
    });

    test('converts bare 9 format to 09 format', () {
      expect(PhoneNumberUtils.normalize('9171234567'), '09171234567');
    });

    test('removes spaces and punctuation', () {
      expect(PhoneNumberUtils.normalize('+63 917-123-4567'), '09171234567');
    });
  });
}
