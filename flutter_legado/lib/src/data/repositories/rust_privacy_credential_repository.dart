import '../bridge/rust_errors.dart';
import '../../bridge/ffi.dart' as bridge;
import '../../domain/contracts/privacy_credential_repository.dart';

/// 凭据摘要由 Rust 数据层拥有。— Codex + Bridge
class RustPrivacyCredentialRepository implements PrivacyCredentialRepository {
  const RustPrivacyCredentialRepository();
  @override
  Future<bool> hasPassword() => rustFuture(
    () => bridge.privacyHasPassword(),
    operation: 'privacyHasPassword',
  );
  @override
  Future<bool> verify(String password) => rustFuture(
    () => bridge.privacyVerifyPassword(password: password),
    operation: 'privacyVerifyPassword',
  );
  @override
  Future<bool> change(String currentPassword, String password) => rustFuture(
    () => bridge.privacySetPassword(
      currentPassword: currentPassword,
      password: password,
    ),
    operation: 'privacySetPassword',
  );
}
