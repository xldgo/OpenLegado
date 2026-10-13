import '../../domain/contracts/source_login_repository.dart';
import '../../domain/models/source_login_credentials.dart';
import '../../domain/services/source_login_codec.dart';

/// 组织手动凭据加载与保存，不持有 UI 状态或根 API。— Codex + Bridge
final class SourceLoginService {
  SourceLoginService({
    required this._repository,
    required this._readLegacy,
    required this._clearLegacy,
    this._codec = const SourceLoginCodec(),
  });

  final SourceLoginRepository _repository;
  final Future<String?> Function(String url) _readLegacy;
  final Future<void> Function(String url) _clearLegacy;
  final SourceLoginCodec _codec;

  Future<SourceLoginCredentials> load(String url) async {
    final info = await _repository.getLoginInfo(url);
    final header = await _repository.getLoginHeader(url);
    if (info.isEmpty && header.isEmpty) {
      final raw = await _readLegacy(url);
      if (raw != null && raw.isNotEmpty) return _codec.decodeLegacy(raw);
    }
    return _codec.decode(info, header);
  }

  /// 保留 Header→Info 的非事务写入；仅两次成功后尽力清理旧配置。
  Future<void> save(String url, SourceLoginCredentials value) async {
    final json = _codec.encode(value);
    await _repository.putLoginHeader(url, json.headerJson);
    await _repository.putLoginInfo(url, json.infoJson);
    try {
      await _clearLegacy(url);
    } catch (_) {}
  }
}
