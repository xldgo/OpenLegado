/// 单份封面规则配置；保留未在编辑器展示的Cookie开关。— Codex + Bridge
final class CoverRule {
  const CoverRule({
    this.enable = true,
    this.searchUrl = '',
    this.coverRule = '',
    this.enabledCookieJar,
  });
  final bool enable;
  final String searchUrl;
  final String coverRule;
  final bool? enabledCookieJar;
}
