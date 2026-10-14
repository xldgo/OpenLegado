import '../../bridge/ffi.dart' as bridge;
import '../../domain/contracts/privacy_credential_repository.dart';

/// 凭据摘要由 Rust 数据层拥有。— Codex + Bridge
class RustPrivacyCredentialRepository implements PrivacyCredentialRepository {
  const RustPrivacyCredentialRepository();
  @override
  Future<bool> hasPassword() => bridge.privacyHasPassword();
  @override
  Future<bool> verify(String password) =>
      bridge.privacyVerifyPassword(password: password);
  @override
  Future<bool> change(String currentPassword, String password) => bridge
      .privacySetPassword(currentPassword: currentPassword, password: password);
}
