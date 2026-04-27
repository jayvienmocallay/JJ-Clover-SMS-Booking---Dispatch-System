import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/core/security/database_encryption_key_repository.dart';

void main() {
  test(
    'creates a random SQLCipher key and stores it on first install',
    () async {
      final values = <String, String>{};
      var writeCount = 0;
      final repository = DatabaseEncryptionKeyRepository.fromStorageCallbacks(
        read: ({required key}) async => values[key],
        write: ({required key, required value}) async {
          writeCount += 1;
          values[key] = value;
        },
      );

      final password = await repository.readOrCreate();

      expect(values[DatabaseEncryptionKeyRepository.storageKey], password);
      expect(writeCount, 1);
      expect(
        base64Url.decode(password),
        hasLength(DatabaseEncryptionKeyRepository.keyByteLength),
      );
      expect(password, isNot(contains('random_secure_salt')));
      expect(RegExp(r'^\d+random_secure_salt$').hasMatch(password), isFalse);
    },
  );

  test('keeps existing stored keys for installed databases', () async {
    const legacyPassword = '1714096800000random_secure_salt';
    var writeCount = 0;
    final repository = DatabaseEncryptionKeyRepository.fromStorageCallbacks(
      read: ({required key}) async => legacyPassword,
      write: ({required key, required value}) async {
        writeCount += 1;
      },
    );

    final password = await repository.readOrCreate();

    expect(password, legacyPassword);
    expect(writeCount, 0);
  });

  test('reuses a generated key after it has been stored', () async {
    final values = <String, String>{};
    var writeCount = 0;
    final repository = DatabaseEncryptionKeyRepository.fromStorageCallbacks(
      read: ({required key}) async => values[key],
      write: ({required key, required value}) async {
        writeCount += 1;
        values[key] = value;
      },
    );

    final firstPassword = await repository.readOrCreate();
    final secondPassword = await repository.readOrCreate();

    expect(secondPassword, firstPassword);
    expect(writeCount, 1);
  });
}
