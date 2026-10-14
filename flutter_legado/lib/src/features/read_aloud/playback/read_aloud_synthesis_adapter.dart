import '../../../domain/contracts/cloud_tts_repository.dart';
import '../../../domain/contracts/cloud_tts_synthesizer.dart';
import '../../../domain/contracts/http_tts_synthesizer.dart';
import 'read_aloud_engine.dart';

/// 调度队列只调用注入的操作；源参数映射集中在适配器。— Codex + UI
Future<HttpTtsSynthesisResult> synthesizeReadAloudRequest(
  ReadAloudRequest request,
  HttpTtsCancellation cancellation, {
  required HttpTtsSynthesizer http,
  CloudTtsSynthesizer? cloud,
}) {
  if (isCloudTts(request.engineUrl)) {
    if (cloud == null) throw StateError('云端合成器不可用');
    return cloud.synthesize(
      engineId: cloudTtsId(request.engineUrl),
      text: request.text,
      voiceId: request.voicePresetId,
      voiceOptions: request.cloudVoiceOptions,
      cancellation: cancellation,
    );
  }
  return http.synthesize(
    engineId: request.engineId,
    text: request.text,
    engineUrl: request.engineUrl,
    speed: request.speed,
    pitch: request.pitch,
    volume: request.volume,
    voiceName: request.voiceName,
    toneId: request.toneId,
    speakerName: request.speakerName,
    emotionTag: request.emotionTag,
    cancellation: cancellation,
  );
}
