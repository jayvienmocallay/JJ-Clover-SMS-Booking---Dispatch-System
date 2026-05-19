import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/data/repositories/admin_credential_repository.dart';

AdminCredentialRepository _makeRepo([Map<String, String>? store]) {
  final values = store ?? <String, String>{};
  return AdminCredentialRepository.fromStorageCallbacks(
    read: ({required key}) async => values[key],
    write: ({required key, required value}) async => values[key] = value,
    delete: ({required key}) async => values.remove(key),
  );
}

void main() {
  test('hasCredentials returns false when nothing stored', () async {
    final repo = _makeRepo();
    expect(await repo.hasCredentials(), isFalse);
  });

  test('setPassword stores salt and hash', () async {
    final store = <String, String>{};
    final repo = _makeRepo(store);
    await repo.setPassword('1234');
    expect(store[AdminCredentialRepository.saltKey], isNotNull);
    expect(store[AdminCredentialRepository.hashKey], isNotNull);
    expect(store[AdminCredentialRepository.hashKey], isNot('1234'));
  });

  test('hasCredentials returns true after setPassword', () async {
    final repo = _makeRepo();
    await repo.setPassword('1234');
    expect(await repo.hasCredentials(), isTrue);
  });

  test('verify returns true for correct password', () async {
    final repo = _makeRepo();
    await repo.setPassword('secret');
    expect(await repo.verify('secret'), isTrue);
  });

  test('verify returns false for wrong password', () async {
    final repo = _makeRepo();
    await repo.setPassword('secret');
    expect(await repo.verify('wrong'), isFalse);
  });

  test('verify returns false when no credentials stored', () async {
    final repo = _makeRepo();
    expect(await repo.verify('anything'), isFalse);
  });

  test('different passwords produce different hashes', () async {
    final store1 = <String, String>{};
    final store2 = <String, String>{};
    final repo1 = _makeRepo(store1);
    final repo2 = _makeRepo(store2);
    await repo1.setPassword('aaaa');
    await repo2.setPassword('bbbb');
    expect(
      store1[AdminCredentialRepository.hashKey],
      isNot(store2[AdminCredentialRepository.hashKey]),
    );
  });

  test('clear removes stored credentials', () async {
    final repo = _makeRepo();
    await repo.setPassword('1234');
    await repo.clear();
    expect(await repo.hasCredentials(), isFalse);
    expect(await repo.verify('1234'), isFalse);
  });
}
