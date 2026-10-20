/// HTTP音色选择值，不包含引擎实体或播放状态。— Codex + Bridge
final class HttpTtsVoiceSelection {
  const HttpTtsVoiceSelection(this.voiceId, {this.emotionTag});
  final String voiceId;
  final String? emotionTag;
}
