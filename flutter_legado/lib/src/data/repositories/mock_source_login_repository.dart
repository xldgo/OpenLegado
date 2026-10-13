import '../../domain/contracts/source_login_repository.dart';

/// 每个根实例拥有唯一凭据存储，保留原始字符串与空值。— Codex + Bridge
final class MockSourceLoginRepository implements SourceLoginRepository {
  final Map<String, String> _mockLoginInfo = {};
  final Map<String, String> _mockLoginHeader = {};

  @override
  Future<void> putLoginInfo(String sourceUrl, String infoJson) async {
    // Mock：内存态保存，供 USE_MOCK 开发模式联调
    _mockLoginInfo[sourceUrl] = infoJson;
  }

  @override
  Future<void> putLoginHeader(String sourceUrl, String headerJson) async {
    _mockLoginHeader[sourceUrl] = headerJson;
  }

  @override
  Future<String> getLoginInfo(String sourceUrl) async =>
      _mockLoginInfo[sourceUrl] ?? '';

  @override
  Future<String> getLoginHeader(String sourceUrl) async =>
      _mockLoginHeader[sourceUrl] ?? '';
}
