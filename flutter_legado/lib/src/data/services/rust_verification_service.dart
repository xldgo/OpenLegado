import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/verification_service.dart';
import '../../domain/models/verification_request.dart';
import '../bridge/source_request_json.dart';

/// 既有长期流与请求key原样传递。— Codex + Bridge
class RustVerificationService implements VerificationService {
  const RustVerificationService();
  @override
  Stream<VerificationRequest> verificationRequestStream() =>
      bridge.verificationRequestStream().map(decodeVerificationRequest);
  @override
  Future<bool> submitVerificationResult(String key, String code) =>
      bridge.verificationSubmit(key: key, code: code);
  @override
  Future<bool> cancelVerificationRequest(String key) =>
      bridge.verificationCancel(key: key);
}
