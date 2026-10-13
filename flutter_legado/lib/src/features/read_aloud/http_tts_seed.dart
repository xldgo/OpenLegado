import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../domain/contracts/http_tts_repository.dart';

/// 对齐 Android `LocalConfig.needUpHttpTts` 的版本号（首启/升级导入种子）
const kHttpTtsSeedVersionKey = 'httpTtsSeedVersion';
const kHttpTtsSeedVersion = 1;

/// 默认 HTTP TTS 引擎种子（对齐 `app/src/main/assets/defaultData/httpTTS.json`）
const kDefaultHttpTtsAsset = 'assets/default_data/httpTTS.json';

/// 判断引擎 URL 模板是否与当前 Rust 合成管线兼容（仅用于自动选默认引擎）。
///
/// Rust `tts_speak` 的能力边界（rust/legado-core/src/tts_speak.rs）：
/// 纯 GET URL + `{{speakText}}`/`{{text}}`/`{{speakSpeed}}`/`{{speed}}`
/// 占位符替换。原版种子引擎依赖其不支持的能力——
/// `url,{json}` POST 模板、`@js:` 动态 URL、loginUrl 登录链路——
/// 被选中即合成失败（QA 实测种子「1.百度」无参数返回错误 JSON）。
/// 因此自动选默认引擎时必须跳过这些模板，避免让用户误以为引擎可用。
bool isCompatibleHttpTtsEngineUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  if (!trimmed.startsWith('http')) return false;
  if (trimmed.startsWith('@js:')) return false;
  // `url,{...}`：原版 AnalyzeUrl 的 POST/body 模板形态，Rust 管线不支持
  final commaIndex = trimmed.indexOf(',');
  if (commaIndex >= 0 &&
      trimmed.substring(commaIndex + 1).trimLeft().startsWith('{')) {
    return false;
  }
  // 无文本占位符则朗读文本无法带入请求，必然不可用
  return trimmed.contains('{{text}}') || trimmed.contains('{{speakText}}');
}

/// 导入原版 httpTTS 种子（对齐 Android `DefaultData.importDefaultHttpTts`）。
///
/// 「种子确实存在且不为空」才导入：资源缺失/为空/解析失败均返回 0，不抛异常。
/// 幂等：按 name+url 跳过库中已有行；库为空时逐条经 FFI 落库。
///
/// 种子按原版形态全量导入、不做启用态标记（原版亦无该概念）：`HttpTTS.kt`
/// 无 `isEnabled` 字段，Flutter `HttpTts` 模型（models/misc.dart）同样没有；
/// 此前导入后调用的 `httpTtsSetEnabled(id,false)` 只会写 Rust 侧超集列
/// `httpTTS.isEnabled`，而无任何消费方（列表走 find_all、合成不读该列）——
/// 属无效写入，已移除。可用性由 [isCompatibleHttpTtsEngineUrl] 在自动选
/// 默认引擎时按 URL 模板能力把关。
Future<int> syncDefaultHttpTts(
  HttpTtsRepository api, {
  String? jsonOverride,
}) async {
  String text;
  if (jsonOverride != null) {
    text = jsonOverride;
  } else {
    try {
      text = await rootBundle.loadString(kDefaultHttpTtsAsset);
    } catch (e) {
      debugPrint('httpTTS 种子资源缺失，跳过导入: $e');
      return 0;
    }
  }
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;

  List<Map<String, dynamic>> seeds;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! List) return 0;
    seeds = decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  } catch (e) {
    debugPrint('httpTTS 种子 JSON 解析失败，跳过导入: $e');
    return 0;
  }
  if (seeds.isEmpty) return 0;

  final List<HttpTts> existingList;
  try {
    existingList = await api.getHttpTts();
  } catch (e) {
    debugPrint('读取已有朗读引擎失败，中止种子同步（保护已有配置）: $e');
    return 0;
  }

  final existingIds = <int>{};
  final existingNameUrls = <String>{};
  for (final engine in existingList) {
    if (engine.id != 0) {
      existingIds.add(engine.id);
    }
    existingNameUrls.add('${engine.name}\u0000${engine.url}');
  }

  var imported = 0;
  for (final seed in seeds) {
    try {
      final rawName = seed['name'];
      final rawUrl = seed['url'];
      if (rawName is! String || rawUrl is! String) continue;
      final name = rawName.trim();
      final url = rawUrl.trim();
      if (name.isEmpty || url.isEmpty) continue;

      final parsed = HttpTts.fromJson(seed).copyWith(
        name: name,
        url: url,
      );

      // 稳定身份防护：若已有记录中已存在该 ID（如负数预设 ID）或相同的名称+URL，跳过导入以保护用户配置
      if (parsed.id != 0 && existingIds.contains(parsed.id)) {
        continue;
      }
      final nameUrlKey = '${parsed.name}\u0000${parsed.url}';
      if (existingNameUrls.contains(nameUrlKey)) {
        continue;
      }

      await api.addHttpTts(parsed);
      if (parsed.id != 0) existingIds.add(parsed.id);
      existingNameUrls.add(nameUrlKey);
      imported++;
    } catch (e) {
      debugPrint('httpTTS 种子单条解析或导入失败，跳过该条: $e');
    }
  }
  return imported;
}

/// 首启/版本升级导入一次种子（SharedPreferences 版本门控，对标 dict/rss/txtToc）。
///
/// [jsonOverride] 仅测试/迁移用：显式种子 JSON 覆盖资源读取。
/// 失败不阻塞朗读链路（调用方仍按无引擎降级估算）。
Future<void> ensureDefaultHttpTts(
  HttpTtsRepository api, {
  String? jsonOverride,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(kHttpTtsSeedVersionKey) ?? 0;
    if (version >= kHttpTtsSeedVersion) return;
    final imported = await syncDefaultHttpTts(api, jsonOverride: jsonOverride);
    if (imported > 0) {
      await prefs.setInt(kHttpTtsSeedVersionKey, kHttpTtsSeedVersion);
    }
  } catch (e) {
    debugPrint('httpTTS 种子导入跳过（不影响朗读）: $e');
  }
}
