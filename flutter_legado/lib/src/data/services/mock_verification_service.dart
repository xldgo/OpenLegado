import '../../domain/contracts/verification_service.dart';
import '../../domain/models/verification_request.dart';

/// 无真实JS请求，提交和取消均返回未命中。— Codex + Bridge
class MockVerificationService implements VerificationService {
  const MockVerificationService();
  @override
  Stream<VerificationRequest> verificationRequestStream() =>
      const Stream.empty();
  @override
  Future<bool> submitVerificationResult(String key, String code) async => false;
  @override
  Future<bool> cancelVerificationRequest(String key) async => false;
}
