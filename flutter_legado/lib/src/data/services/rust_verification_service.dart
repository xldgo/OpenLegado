import '../bridge/rust_errors.dart';
import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/verification_service.dart';
import '../../domain/models/verification_request.dart';
import '../bridge/task_dto_mapping.dart';
import '../bridge/managed_rust_stream.dart';

/// 既有长期流与请求key原样传递。— Codex + Bridge
class RustVerificationService implements VerificationService {
  const RustVerificationService();
  @override
  Stream<VerificationRequest> verificationRequestStream() => managedRustStream(
    (request) => rustStream(
      () => bridge.verificationRequestStream(request: request),
      operation: 'verificationRequestStream',
    ),
  ).map(verificationFromDto);
  @override
  Future<bool> submitVerificationResult(String key, String code) => rustFuture(
    () => bridge.verificationSubmit(key: key, code: code),
    operation: 'verificationSubmit',
  );
  @override
  Future<bool> cancelVerificationRequest(String key) => rustFuture(
    () => bridge.verificationCancel(key: key),
    operation: 'verificationCancel',
  );
}
