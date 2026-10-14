/// 隐私凭据操作，不向 UI 暴露密码摘要。— Codex + Bridge
abstract interface class PrivacyCredentialRepository {
  Future<bool> hasPassword();
  Future<bool> verify(String password);
  Future<bool> change(String currentPassword, String password);
}
