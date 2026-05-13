import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('another_telephony is not imported anywhere in lib/', () {
    final libDir = Directory('lib');
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    final offenders = <String>[];
    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      if (content.contains('package:another_telephony') ||
          RegExp(r'\bTelephony\b').hasMatch(content)) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Found another_telephony or Telephony references in: $offenders',
    );
  });
}
