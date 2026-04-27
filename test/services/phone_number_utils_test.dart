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

  group('PhoneNumberUtils.isAcceptedCustomerPhone', () {
    test('accepts local 09 mobile numbers with 11 digits', () {
      expect(PhoneNumberUtils.isAcceptedCustomerPhone('09171234567'), isTrue);
    });

    test('rejects international and punctuated forms for customer entry', () {
      expect(
        PhoneNumberUtils.isAcceptedCustomerPhone('+639171234567'),
        isFalse,
      );
      expect(
        PhoneNumberUtils.isAcceptedCustomerPhone('+63 917-123-4567'),
        isFalse,
      );
      expect(PhoneNumberUtils.isAcceptedCustomerPhone('9171234567'), isFalse);
    });

    test('rejects invalid local lengths and prefixes', () {
      expect(PhoneNumberUtils.isAcceptedCustomerPhone('0917123456'), isFalse);
      expect(PhoneNumberUtils.isAcceptedCustomerPhone('091712345678'), isFalse);
      expect(PhoneNumberUtils.isAcceptedCustomerPhone('08171234567'), isFalse);
    });
  });
}
