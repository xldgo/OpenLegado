import '../../models/book_source.dart';

/// 书源校验能力；不拥有配置、页面状态或数据库初始化。— Codex + UI
abstract interface class SourceChecker {
  /// 校验单个书源（搜索→详情→目录→正文四步 + 验证码/重定向检测）
  ///
  /// [source] — 已由书源导入或仓储解析的实体，不重复序列化。
  /// [configJson] — 可选校验配置 JSON：`keyword` / `step_timeout_ms` /
  /// `check_search` / `check_toc` / `check_content` / `detect_captcha` /
  /// `detect_redirect`，全部可选，缺省用默认配置。
  ///
  /// 返回 CheckResult Map，字段：`source_url` / `search_ok` / `toc_ok` /
  /// `content_ok` / `search_error` / `toc_error` / `content_error` /
  /// `total_time_ms` / `captcha`（detected/captcha_type/matched_keyword）/
  /// `redirect`（redirected/original_url/final_url/is_login_redirect）。
  Future<Map<String, dynamic>> checkSource(
    BookSource source, {
    String? configJson,
  });

  /// 批量校验书源（串行逐个回推进度，对齐 Kotlin CheckSourceService）
  ///
  /// [sourceUrls] — 待校验书源 URL 列表；空列表校验全部书源。
  /// [configJson] — 可选校验配置 JSON，同 [checkSource]。
  ///
  /// 每完成一个书源推送一条进度 Map，字段：`index`（从 0 开始）/
  /// `total` / `is_last` / `source_name` / `result`（CheckResult，
  /// 字段同 [checkSource]）。流在所有书源完成或取消后自然结束。
  Stream<Map<String, dynamic>> checkSourcesStream(
    List<String> sourceUrls, {
    String? configJson,
  });

  /// 取消正在进行的批量书源校验
  Future<void> cancelCheckSources();
}
