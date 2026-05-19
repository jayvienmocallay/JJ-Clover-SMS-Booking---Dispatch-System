import '../../data/repositories/admin_credential_repository.dart';

abstract class AdminAuthService {
  Future<bool> isAdminConfigured();
  bool get isUnlocked;
  Future<bool> verifyPassword(String password);
  Future<void> unlockFor({Duration duration = const Duration(minutes: 5)});
  Future<void> lock();
  Future<void> setPassword(String password);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

class DefaultAdminAuthService implements AdminAuthService {
  DefaultAdminAuthService({required AdminCredentialRepository credentialRepository})
      : _repo = credentialRepository;

  final AdminCredentialRepository _repo;
  DateTime? _unlockedUntil;

  @override
  Future<bool> isAdminConfigured() => _repo.hasCredentials();

  @override
  bool get isUnlocked {
    if (_unlockedUntil == null) return false;
    if (DateTime.now().isAfter(_unlockedUntil!)) {
      _unlockedUntil = null;
      return false;
    }
    return true;
  }

  @override
  Future<bool> verifyPassword(String password) => _repo.verify(password);

  @override
  Future<void> unlockFor({Duration duration = const Duration(minutes: 5)}) async {
    _unlockedUntil = DateTime.now().add(duration);
  }

  @override
  Future<void> lock() async {
    _unlockedUntil = null;
  }

  @override
  Future<void> setPassword(String password) => _repo.setPassword(password);

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final valid = await _repo.verify(currentPassword);
    if (!valid) throw StateError('Incorrect current password.');
    await _repo.setPassword(newPassword);
  }
}
