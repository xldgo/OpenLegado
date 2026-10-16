import 'dart:convert';

import '../../domain/models/http_tts_voice_selection.dart';
export '../../domain/models/http_tts_voice_selection.dart';

import '../../domain/contracts/read_aloud_voice_repository.dart';

final class HttpTtsVoiceResolution {
  const HttpTtsVoiceResolution({this.voice, this.emotionTag, this.warning});
  final ReadAloudVoice? voice;
  final String? emotionTag, warning;
}

/// 只解析已持久化选择，不在排除/缺失时偷偷换为另一个目录音色。
HttpTtsVoiceResolution resolveHttpTtsVoice(
  int engineId,
  List<ReadAloudVoice> catalog,
  HttpTtsVoiceSelection? selection,
) {
  if (selection == null) return const HttpTtsVoiceResolution();
  final voice = catalog
      .where(
        (v) =>
            v.id == selection.voiceId &&
            v.engineType == 'http' &&
            v.engineId == '$engineId',
      )
      .firstOrNull;
  if (voice == null || !voice.selectable) {
    return const HttpTtsVoiceResolution(warning: '所选音色不可用，使用引擎默认音色');
  }
  final emotions = (jsonDecode(voice.emotionCatalogJson) as List).cast<Map>();
  final emotion = selection.emotionTag;
  if (emotion != null && emotions.every((e) => e['emotionTag'] != emotion)) {
    return HttpTtsVoiceResolution(voice: voice, warning: '所选情感已不在目录中，使用默认情感');
  }
  return HttpTtsVoiceResolution(voice: voice, emotionTag: emotion);
}
