import 'package:flutter_test/flutter_test.dart';
import 'package:jj_clover_sms/core/security/admin_auth_service.dart';
import 'package:jj_clover_sms/data/repositories/admin_credential_repository.dart';

DefaultAdminAuthService _makeService([Map<String, String>? store]) {
  final values = store ?? <String, String>{};
  final repo = AdminCredentialRepository.fromStorageCallbacks(
    read: ({required key}) async => values[key],
    write: ({required key, required value}) async => values[key] = value,
    delete: ({required key}) async => values.remove(key),
  );
  return DefaultAdminAuthService(credentialRepository: repo);
}

void main() {
  test('isAdminConfigured returns false when no PIN set', () async {
    final svc = _makeService();
    expect(await svc.isAdminConfigured(), isFalse);
  });

  test('isAdminConfigured returns true after setPassword', () async {
    final svc = _makeService();
    await svc.setPassword('1234');
    expect(await svc.isAdminConfigured(), isTrue);
  });

  test('isUnlocked is false initially', () {
    final svc = _makeService();
    expect(svc.isUnlocked, isFalse);
  });

  test('isUnlocked is true after unlockFor', () async {
    final svc = _makeService();
    await svc.unlockFor(duration: const Duration(minutes: 5));
    expect(svc.isUnlocked, isTrue);
  });

  test('isUnlocked is false after lock', () async {
    final svc = _makeService();
    await svc.unlockFor(duration: const Duration(minutes: 5));
    await svc.lock();
    expect(svc.isUnlocked, isFalse);
  });

  test('isUnlocked expires after duration elapses', () async {
    final svc = _makeService();
    await svc.unlockFor(duration: const Duration(milliseconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(svc.isUnlocked, isFalse);
  });

  test('verifyPassword returns true for correct PIN', () async {
    final svc = _makeService();
    await svc.setPassword('mypin');
    expect(await svc.verifyPassword('mypin'), isTrue);
  });

  test('verifyPassword returns false for wrong PIN', () async {
    final svc = _makeService();
    await svc.setPassword('mypin');
    expect(await svc.verifyPassword('wrong'), isFalse);
  });

  test('changePassword succeeds with correct current PIN', () async {
    final svc = _makeService();
    await svc.setPassword('old');
    await svc.changePassword(currentPassword: 'old', newPassword: 'new');
    expect(await svc.verifyPassword('new'), isTrue);
    expect(await svc.verifyPassword('old'), isFalse);
  });

  test('changePassword throws on wrong current PIN', () async {
    final svc = _makeService();
    await svc.setPassword('old');
    expect(
      () => svc.changePassword(currentPassword: 'bad', newPassword: 'new'),
      throwsA(isA<StateError>()),
    );
  });
}
