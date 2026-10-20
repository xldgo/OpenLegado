import '../../../domain/contracts/http_tts_synthesizer.dart';
import 'file_read_aloud_engine.dart';
import 'read_aloud_synthesis_queue.dart';

/// HTTP 只提供合成入口，文件播放生命周期由共用实现负责。— Codex + UI
final class HttpReadAloudEngine extends FileReadAloudEngine {
  HttpReadAloudEngine({
    required HttpTtsSynthesizer Function() synthesizer,
    required super.player,
    ReadAloudSynthesisQueue? queue,
  }) : super(
         synthesize: (request, cancellation) => queue != null
             ? queue.foreground(request, cancellation)
             : synthesizer().synthesize(
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
               ),
       );
}
