import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/source_checker.dart';
import '../bridge/rust_json_decode.dart';

/// 直接使用现有 FRB；不创建数据库或另一份校验任务。— Codex + Bridge
final class RustSourceChecker implements SourceChecker {
  const RustSourceChecker();

  // ========== 书源校验（Task #87） ==========

  /// 校验单个书源（搜索→详情→目录→正文四步 + 验证码/重定向检测）
  ///
  /// Rust 侧返回 CheckResult JSON，字段见 [SourceChecker.checkSource]。
  @override
  Future<Map<String, dynamic>> checkSource(
    String sourceJson, {
    String? configJson,
  }) async {
    final json = await bridge.sourceCheck(
      sourceJson: sourceJson,
      configJson: configJson ?? '',
    );
    return decodeRustJsonMap(json, 'checkSource');
  }

  /// 批量校验书源（串行逐个回推进度）
  ///
  /// 每完成一个书源推送一条进度 Map，字段见 [SourceChecker.checkSourcesStream]。
  @override
  Stream<Map<String, dynamic>> checkSourcesStream(
    List<String> sourceUrls, {
    String? configJson,
  }) {
    final urlsJson = jsonEncode(sourceUrls);
    return bridge
        .sourceCheckStream(
          sourceUrlsJson: urlsJson,
          configJson: configJson ?? '',
        )
        .map((item) => decodeRustJsonMap(item, 'checkSourcesStream'));
  }

  /// 取消正在进行的批量书源校验
  @override
  Future<void> cancelCheckSources() => bridge.sourceCheckCancel();
}
