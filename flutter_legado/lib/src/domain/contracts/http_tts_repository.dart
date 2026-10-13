import '../../models/models.dart';

/// 只管理 HTTP 朗读引擎配置；系统语音与播放会话有独立职责。— Codex + UI
abstract interface class HttpTtsRepository {
  // ========== HTTP TTS ==========

  /// 获取所有 HTTP TTS 配置
  Future<List<HttpTts>> getHttpTts();

  /// 添加 HTTP TTS 配置
  Future<HttpTts> addHttpTts(HttpTts tts);

  /// 更新 HTTP TTS 配置
  Future<void> updateHttpTts(HttpTts tts);

  /// 删除 HTTP TTS 配置
  Future<void> deleteHttpTts(int id);

  /// 导入 HTTP TTS 配置
  Future<int> importHttpTts(String json);

  /// 导出 HTTP TTS 配置
  Future<String> exportHttpTts();

  /// 设置 HTTP TTS 源启用/禁用（F3-20）
  Future<bool> httpTtsSetEnabled(int id, bool enabled);
}
