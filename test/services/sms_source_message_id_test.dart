import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/services/sms_source_message_id.dart';

void main() {
  group('SmsSourceMessageId', () {
    test('builds deterministic IDs from normalized sender and body hash', () {
      final id = SmsSourceMessageId.build(
        sender: '+63 917 123 4567',
        message: 'DELIVER 1',
        timestamp: 1710000000000,
        subscriptionId: 2,
      );

      expect(
        id,
        '09171234567|1710000000000|2|'
        '47bb6986f0c01292e9f0e46c7a046a20e481c01625f07a208b4e3f582378bf84',
      );
    });

    test('uses sentinel values for absent timestamp and subscription', () {
      final id = SmsSourceMessageId.build(
        sender: '09171234567',
        message: 'STATUS',
      );

      expect(id, startsWith('09171234567|-1|-1|'));
    });
  });
}
