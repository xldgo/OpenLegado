import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/http_tts_repository.dart';
import '../../models/models.dart';
import '../bridge/rust_json_decode.dart';

/// HTTP 引擎配置直接访问既有 FRB，不承担初始化或朗读。— Codex + Bridge
final class RustHttpTtsRepository implements HttpTtsRepository {
  const RustHttpTtsRepository();

  // ========== HTTP TTS ==========

  /// 获取所有 HTTP TTS 配置
  @override
  Future<List<HttpTts>> getHttpTts() async {
    final json = await bridge.httpTtsList();
    final list = decodeRustJsonList(json, 'bookApi');
    return list
        .map((e) => HttpTts.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 添加 HTTP TTS 配置
  @override
  Future<HttpTts> addHttpTts(HttpTts tts) async {
    final id = await bridge.httpTtsAdd(name: tts.name, url: tts.url);
    return tts.copyWith(id: id.toInt());
  }

  /// 更新 HTTP TTS 配置
  @override
  Future<void> updateHttpTts(HttpTts tts) async {
    await bridge.httpTtsUpdate(id: tts.id, name: tts.name, url: tts.url);
  }

  /// 删除 HTTP TTS 配置
  @override
  Future<void> deleteHttpTts(int id) async {
    await bridge.httpTtsDelete(id: id);
  }

  /// 导入 HTTP TTS 配置（解析 JSON 数组并逐条添加）
  @override
  Future<int> importHttpTts(String json) async {
    final list = decodeRustJsonList(json, 'bookApi');
    var count = 0;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final name = m['name'] as String? ?? '';
      final url = m['url'] as String? ?? '';
      if (name.isNotEmpty && url.isNotEmpty) {
        await bridge.httpTtsAdd(name: name, url: url);
        count++;
      }
    }
    return count;
  }

  /// 导出 HTTP TTS 配置（返回 JSON 数组）
  @override
  Future<String> exportHttpTts() async {
    final list = await getHttpTts();
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  /// 设置 HTTP TTS 源启用/禁用（F3-20）
  @override
  Future<bool> httpTtsSetEnabled(int id, bool enabled) =>
      bridge.httpTtsSetEnabled(id: id, enabled: enabled);
}
