import '../../../domain/contracts/http_tts_synthesizer.dart';
import '../../../services/stream_audio_player.dart';
import 'read_aloud_engine.dart';

/// 合成与文件播放适配，不维护正文队列或另存缓存。— Codex + UI
final class HttpReadAloudEngine implements ReadAloudEngine {
  HttpReadAloudEngine({required this._synthesizer, required this._player});

  // 每次请求读取当前注入，保持根装配被替换后的合成行为。
  final HttpTtsSynthesizer Function() _synthesizer;
  // 播放器与音频书共享，不在此注册回调或销毁它。
  final StreamAudioPlayer _player;
  ReadAloudSession? _session;
  int _textLength = 0;

  @override
  bool get canResume => false;

  @override
  Future<ReadAloudStart> speak(
    ReadAloudRequest request,
    ReadAloudSession session,
  ) async {
    if (!session.isCurrent) return ReadAloudStart.cancelled;
    _session?.cancel();
    _session = session;
    _textLength = request.text.length;
    final result = await _synthesizer().synthesize(
      text: request.text,
      engineUrl: request.engineUrl,
      speed: request.speed,
      pitch: request.pitch,
      volume: request.volume,
      voiceName: request.voiceName,
    );
    if (!session.isCurrent) return ReadAloudStart.cancelled;
    if (result is! HttpTtsAudio || result.audioPath.trim().isEmpty) {
      return ReadAloudStart.noAudio;
    }
    // 语速已由合成应用；本地播放不得二次变速。
    await _player.playLocalFile(
      result.audioPath.trim(),
      speed: 1.0,
      tag: session,
    );
    return session.isCurrent
        ? ReadAloudStart.started
        : ReadAloudStart.cancelled;
  }

  /// 由共享播放器的原回调分发；音频书标签和旧段会话不会被接受。
  void handleCompleted(Object? tag) {
    if (identical(tag, _session)) _session?.complete();
  }

  void handleProgress(Duration position, Duration duration, Object? tag) {
    if (!identical(tag, _session) || duration.inMilliseconds <= 0) return;
    final offset =
        (_textLength * position.inMilliseconds / duration.inMilliseconds)
            .floor()
            .clamp(0, _textLength > 0 ? _textLength - 1 : 0);
    _session?.reportProgress(offset);
  }

  @override
  Future<void> pause() => stop();

  @override
  Future<void> stop() {
    _session?.cancel();
    _session = null;
    return _player.stop();
  }

  @override
  Future<ReadAloudStart> resume(ReadAloudSession session) =>
      Future.error(UnsupportedError('HTTP 朗读暂停后需要重新朗读当前段'));
}
