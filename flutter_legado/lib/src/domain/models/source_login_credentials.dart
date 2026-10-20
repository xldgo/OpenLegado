import '../../models/misc.dart' show LoginKeyValue;

/// 手动凭据的不可变编辑快照，不替代仓库中的原始 JSON。— Codex + UI
final class SourceLoginCredentials {
  SourceLoginCredentials({
    this.token = '',
    List<LoginKeyValue> cookies = const [],
    List<LoginKeyValue> headers = const [],
  }) : cookies = List.unmodifiable(cookies),
       headers = List.unmodifiable(headers);

  final String token;
  final List<LoginKeyValue> cookies;
  final List<LoginKeyValue> headers;
}
