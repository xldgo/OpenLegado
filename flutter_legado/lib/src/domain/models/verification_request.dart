/// 验证码请求的原始身份与展示信息。— Codex + Bridge
class VerificationRequest {
  const VerificationRequest({
    required this.key,
    this.sourceUrl = '',
    this.sourceName = '',
    this.imageUrl = '',
    this.title = '',
    this.useBrowser = false,
    this.createdAtMs = 0,
  });
  final String key;
  final String sourceUrl;
  final String sourceName;
  final String imageUrl;
  final String title;
  final bool useBrowser;
  final int createdAtMs;
}
