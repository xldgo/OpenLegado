import 'dart:convert';

import '../../domain/contracts/config_repository.dart';
import '../../domain/contracts/read_aloud_selection_repository.dart';
import '../../domain/models/http_tts_voice_selection.dart';

/// 引擎与音色选择沿用原键；书级覆盖仍由书籍仓储保存。— Codex + Bridge
class ConfigReadAloudSelectionRepository
    implements ReadAloudSelectionRepository {
  const ConfigReadAloudSelectionRepository(this.config);
  final ConfigRepository config;
  @override
  Future<String?> getEngineUrl() => config.getConfig('appTtsEngine');
  @override
  Future<int?> getHttpEngineId() async =>
      int.tryParse(await config.getConfig('appTtsEngineId') ?? '');
  @override
  Future<void> setEngine(String url, {int? httpEngineId}) async {
    if (url.isNotEmpty) await config.setConfig('appTtsEngine', url);
    if (httpEngineId != null && httpEngineId != 0) {
      await config.setConfig('appTtsEngineId', '$httpEngineId');
    } else if (url == 'system://default' || url.startsWith('cloud://')) {
      await config.setConfig('appTtsEngineId', '');
    }
  }

  @override
  Future<String?> getCloudVoice(String engineId) =>
      config.getConfig('cloudTtsVoice:$engineId');
  @override
  Future<void> setCloudVoice(String engineId, String? voiceId) =>
      config.setConfig('cloudTtsVoice:$engineId', voiceId ?? '');
  @override
  Future<HttpTtsVoiceSelection?> getHttpVoice(int engineId) async {
    final raw = await config.getConfig('ttsVoice:$engineId');
    if (raw == null || raw.isEmpty) return null;
    final value = jsonDecode(raw) as Map<String, dynamic>;
    return HttpTtsVoiceSelection(
      value['voiceId'] as String,
      emotionTag: value['emotionTag'] as String?,
    );
  }

  @override
  Future<void> setHttpVoice(int engineId, HttpTtsVoiceSelection? selection) =>
      config.setConfig(
        'ttsVoice:$engineId',
        selection == null
            ? ''
            : jsonEncode({
                'voiceId': selection.voiceId,
                'emotionTag': selection.emotionTag,
              }),
      );
}
