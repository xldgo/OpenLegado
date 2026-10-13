import 'dart:convert';

import '../../domain/contracts/read_aloud_voice_repository.dart';

final class HttpTtsVoiceSelection {
  const HttpTtsVoiceSelection(this.voiceId, {this.emotionTag});
  final String voiceId;
  final String? emotionTag;
  static String key(int id) => 'ttsVoice:$id';
  static HttpTtsVoiceSelection? decode(String? value) {
    if (value == null || value.isEmpty) return null;
    final j = jsonDecode(value) as Map<String, dynamic>;
    return HttpTtsVoiceSelection(
      j['voiceId'] as String,
      emotionTag: j['emotionTag'] as String?,
    );
  }

  String encode() => jsonEncode({'voiceId': voiceId, 'emotionTag': emotionTag});
}

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
