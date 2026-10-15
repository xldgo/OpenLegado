import 'dart:convert';

import '../bridge/rust_json_decode.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/rss_source_repository.dart';
import '../../models/models.dart';
import 'rss_json_decode.dart';

/// 直接复用既有FRB，不持有页面状态。— Codex + Bridge
final class RustRssSourceRepository implements RssSourceRepository {
  const RustRssSourceRepository();

  /// 获取所有 RSS 源
  @override
  Future<List<RssSource>> getRssSources() async {
    final json = await bridge.rssListSources();
    return decodeRssList(json, 'getRssSources', RssSource.fromJson);
  }

  /// 添加 RSS 源
  @override
  Future<RssSource> addRssSource(RssSource source) async {
    final json = await bridge.rssAddSource(
      sourceJson: jsonEncode(source.toJson()),
    );
    return decodeRssObject(
      decodeRustJsonMap(json, 'addRssSource'),
      'addRssSource',
      RssSource.fromJson,
    );
  }

  /// 原子更新RSS实体，不写入书源表。
  @override
  Future<void> updateRssSource(RssSource source) async {
    final json = await bridge.rssUpdateSource(
      sourceJson: jsonEncode(source.toJson()),
    );
    if (jsonDecode(json) == false) {
      throw StateError(
        'updateRssSource: RSS 源不存在（sourceUrl=${source.sourceUrl}）',
      );
    }
    decodeRssObject(
      decodeRustJsonMap(json, 'updateRssSource'),
      'updateRssSource',
      RssSource.fromJson,
    );
  }

  /// 删除 RSS 源
  @override
  Future<void> deleteRssSource(String sourceUrl) =>
      bridge.rssDeleteSource(sourceUrl: sourceUrl);

  /// 通过RSS原子更新启用，保留实体其他字段。
  @override
  Future<void> enableRssSource(String sourceUrl) =>
      _setEnabled(sourceUrl, true);

  /// 通过RSS原子更新禁用，保留实体其他字段。
  @override
  Future<void> disableRssSource(String sourceUrl) =>
      _setEnabled(sourceUrl, false);

  /// 导入 RSS 源（契约 importRssSources）
  ///
  /// 历史误接 `sourceImport`（写入书源表）。现改为逐条 `rssAddSource`
  /// 全字段落 `rssSources`；待 FRB 生成 `rssImportSources` 后可改为批量 FFI。
  @override
  Future<int> importRssSources(String jsonArray) async {
    final decoded = jsonDecode(jsonArray);
    if (decoded is! List) {
      throw FormatException('importRssSources 期望 JSON 数组');
    }
    var count = 0;
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      await addRssSource(RssSource.fromJson(map));
      count++;
    }
    return count;
  }

  /// 导出 RSS 源（契约 exportRssSources；勿走书源 sourceExport）
  @override
  Future<String> exportRssSources() async {
    final sources = await getRssSources();
    return jsonEncode(sources.map((s) => s.toJson()).toList());
  }

  Future<void> _setEnabled(String sourceUrl, bool enabled) async {
    final sources = await getRssSources();
    for (final source in sources) {
      if (source.sourceUrl == sourceUrl) {
        await updateRssSource(source.copyWith(enabled: enabled));
        return;
      }
    }
    throw StateError('RSS 源不存在（sourceUrl=$sourceUrl）');
  }
}
