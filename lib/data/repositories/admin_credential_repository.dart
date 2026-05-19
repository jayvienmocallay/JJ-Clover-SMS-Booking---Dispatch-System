import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef SecureStorageReader = Future<String?> Function({required String key});
typedef SecureStorageWriter =
    Future<void> Function({required String key, required String value});
typedef SecureStorageDeleter = Future<void> Function({required String key});

class AdminCredentialRepository {
  static const saltKey = 'jj_clover_admin_pin_salt';
  static const hashKey = 'jj_clover_admin_pin_hash';

  final SecureStorageReader _read;
  final SecureStorageWriter _write;
  final SecureStorageDeleter _delete;
  final Random Function() _secureRandomFactory;

  factory AdminCredentialRepository({
    FlutterSecureStorage? secureStorage,
    Random Function()? secureRandomFactory,
  }) {
    final storage = secureStorage ?? const FlutterSecureStorage();
    return AdminCredentialRepository.fromStorageCallbacks(
      read: ({required key}) => storage.read(key: key),
      write: ({required key, required value}) =>
          storage.write(key: key, value: value),
      delete: ({required key}) => storage.delete(key: key),
      secureRandomFactory: secureRandomFactory,
    );
  }

  AdminCredentialRepository.fromStorageCallbacks({
    required SecureStorageReader read,
    required SecureStorageWriter write,
    required SecureStorageDeleter delete,
    Random Function()? secureRandomFactory,
  }) : _read = read,
       _write = write,
       _delete = delete,
       _secureRandomFactory = secureRandomFactory ?? Random.secure;

  Future<bool> hasCredentials() async {
    final hash = await _read(key: hashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<bool> verify(String password) async {
    final storedSalt = await _read(key: saltKey);
    final storedHash = await _read(key: hashKey);
    if (storedSalt == null || storedHash == null) return false;
    return _computeHash(storedSalt, password) == storedHash;
  }

  Future<void> setPassword(String password) async {
    final salt = _generateSalt(_secureRandomFactory());
    await _write(key: saltKey, value: salt);
    await _write(key: hashKey, value: _computeHash(salt, password));
  }

  Future<void> clear() async {
    await _delete(key: saltKey);
    await _delete(key: hashKey);
  }

  String _generateSalt(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _computeHash(String salt, String password) {
    final input = '$salt:$password';
    return sha256.convert(utf8.encode(input)).toString();
  }
}
