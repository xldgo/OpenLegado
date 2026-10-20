import '../../domain/contracts/http_tts_synthesizer.dart';

/// Mock 不产生音频，沿用会话的估算推进。— Codex + Bridge
class MockHttpTtsSynthesizer implements HttpTtsSynthesizer {
  const MockHttpTtsSynthesizer();

  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required int engineId,
    required String text,
    String? engineUrl,
    double speed = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
    String? voiceName,
    String? toneId,
    String? speakerName,
    String? emotionTag,
    HttpTtsCancellation? cancellation,
  }) async => const HttpTtsNoAudio(HttpTtsNoAudioReason.mock);
}
