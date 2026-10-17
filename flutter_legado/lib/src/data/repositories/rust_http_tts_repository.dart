import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/http_tts_repository.dart';
import '../../models/models.dart';
import '../bridge/media_dto_mapping.dart';

/// HTTP 引擎配置直接访问既有 FRB，不承担初始化或朗读。— Codex + Bridge
final class RustHttpTtsRepository implements HttpTtsRepository {
  const RustHttpTtsRepository();

  // ========== HTTP TTS ==========

  /// 获取所有 HTTP TTS 配置
  @override
  Future<List<HttpTts>> getHttpTts() async {
    return (await bridge.httpTtsList()).map(httpTtsFromDto).toList();
  }

  /// 添加 HTTP TTS 配置（保存完整字段，返回携带最终 ID 的对象）
  @override
  Future<HttpTts> addHttpTts(HttpTts tts) async {
    final normalized = tts.copyWith(
      synthesisThreadCount: tts.synthesisThreadCount.clamp(
        1,
        kMaxHttpTtsSynthesisThreadCount,
      ),
    );
    final id = await bridge.httpTtsAdd(tts: httpTtsToDto(normalized));
    return normalized.copyWith(id: id.toInt());
  }

  /// 按 ID 原地更新 HTTP TTS 配置；目标不存在或底层失败均抛错
  @override
  Future<void> updateHttpTts(HttpTts tts) async {
    final normalized = tts.copyWith(
      synthesisThreadCount: tts.synthesisThreadCount.clamp(
        1,
        kMaxHttpTtsSynthesisThreadCount,
      ),
    );
    final updated = await bridge.httpTtsUpdate(tts: httpTtsToDto(normalized));
    if (!updated) {
      throw StateError('HTTP TTS 引擎不存在: id=${tts.id}');
    }
  }

  /// 删除 HTTP TTS 配置
  @override
  Future<void> deleteHttpTts(int id) async {
    await bridge.httpTtsDelete(id: id);
  }

  /// 导入 HTTP TTS 配置（解析 JSON 数组，完整保留全字段及数组 loginUi）
  @override
  Future<int> importHttpTts(String json) async {
    return bridge.httpTtsImport(document: json);
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
