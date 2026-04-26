import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef SecureStorageReader = Future<String?> Function({required String key});
typedef SecureStorageWriter =
    Future<void> Function({required String key, required String value});

class DatabaseEncryptionKeyRepository {
  static const String storageKey = 'db_encryption_key';
  static const int keyByteLength = 32;

  final SecureStorageReader _read;
  final SecureStorageWriter _write;
  final Random Function() _secureRandomFactory;

  factory DatabaseEncryptionKeyRepository({
    FlutterSecureStorage? secureStorage,
    Random Function()? secureRandomFactory,
  }) {
    final storage = secureStorage ?? const FlutterSecureStorage();
    return DatabaseEncryptionKeyRepository.fromStorageCallbacks(
      read: ({required key}) => storage.read(key: key),
      write: ({required key, required value}) =>
          storage.write(key: key, value: value),
      secureRandomFactory: secureRandomFactory,
    );
  }

  DatabaseEncryptionKeyRepository.fromStorageCallbacks({
    required SecureStorageReader read,
    required SecureStorageWriter write,
    Random Function()? secureRandomFactory,
  }) : _read = read,
       _write = write,
       _secureRandomFactory = secureRandomFactory ?? Random.secure;

  Future<String> readOrCreate() async {
    final existingKey = await _read(key: storageKey);
    if (existingKey != null) {
      return existingKey;
    }

    final generatedKey = _generateKey(_secureRandomFactory());
    await _write(key: storageKey, value: generatedKey);
    return generatedKey;
  }

  String _generateKey(Random random) {
    final bytes = List<int>.generate(
      keyByteLength,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes);
  }
}
