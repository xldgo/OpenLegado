import '../models/http_tts_voice_selection.dart';

/// 引擎实体之外的用户选择，不管理播放会话或音色目录。— Codex + Bridge
abstract interface class ReadAloudSelectionRepository {
  Future<String?> getEngineUrl();
  Future<int?> getHttpEngineId();
  Future<void> setEngine(String url, {int? httpEngineId});
  Future<String?> getCloudVoice(String engineId);
  Future<void> setCloudVoice(String engineId, String? voiceId);
  Future<HttpTtsVoiceSelection?> getHttpVoice(int engineId);
  Future<void> setHttpVoice(int engineId, HttpTtsVoiceSelection? selection);
}
