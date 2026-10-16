import '../models/verification_request.dart';

/// 订阅与结果回传绑定同一通道实例；false表示请求已不存在。— Codex + Bridge
abstract interface class VerificationService {
  Stream<VerificationRequest> verificationRequestStream();
  Future<bool> submitVerificationResult(String key, String code);
  Future<bool> cancelVerificationRequest(String key);
}
