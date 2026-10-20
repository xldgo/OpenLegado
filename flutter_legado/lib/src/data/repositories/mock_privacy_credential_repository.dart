import '../../domain/contracts/privacy_credential_repository.dart';

/// 仅用于 USE_MOCK 开发模式，凭据不落盘，不承担生产安全存储。— Codex + Bridge
class MockPrivacyCredentialRepository implements PrivacyCredentialRepository {
  String _password = '';
  @override
  Future<bool> hasPassword() async => _password.isNotEmpty;
  @override
  Future<bool> verify(String password) async =>
      _password.isNotEmpty && password == _password;
  @override
  Future<bool> change(String currentPassword, String password) async {
    if (_password.isNotEmpty && currentPassword != _password) return false;
    _password = password;
    return true;
  }
}
