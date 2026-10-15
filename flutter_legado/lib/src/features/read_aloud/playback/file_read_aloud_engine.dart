import '../../../domain/contracts/http_tts_synthesizer.dart';
import '../../../services/stream_audio_player.dart';
import '../../../services/audio_playlist_player.dart';
import 'file_read_aloud_playlist.dart';
import 'read_aloud_engine.dart';

/// 合成与文件播放适配，不维护正文队列或另存缓存。— Codex + UI
class FileReadAloudEngine implements ReadAloudEngine, ReadAloudPlaylistEngine {
  FileReadAloudEngine({required this.synthesize, required this.player});
  final Future<HttpTtsSynthesisResult> Function(
    ReadAloudRequest,
    HttpTtsCancellation,
  )
  synthesize;
  final StreamAudioPlayer player;
  late final FileReadAloudPlaylist? _playlist = player is AudioPlaylistPlayer
      ? FileReadAloudPlaylist(player: player, synthesize: synthesize)
      : null;
  @override
  bool get supportsPlaylist => _playlist != null;
  @override
  Future<ReadAloudStart> speakPlaylist(
    List<ReadAloudPlaylistCue> cues,
    ReadAloudSession session, {
    required void Function(ReadAloudPlaylistCue) onCueStarted,
  }) async {
    if (_playlist!.active) await _playlist.stop();
    if (!session.isCurrent) return ReadAloudStart.cancelled;
    return _playlist.speak(cues, session, onCueStarted: onCueStarted);
  }

  HttpTtsAudio? _audio;
  ReadAloudSession? _session;
  HttpTtsCancellation? _pending;
  int _textLength = 0;
  bool _loaded = false;
  bool _paused = false;
  Future<void> _pauseBarrier = Future.value();

  @override
  bool get canResume => _playlist?.active == true
      ? _playlist!.canResume
      : _paused &&
            _loaded &&
            _session != null &&
            player.isInitialized &&
            identical(player.currentTag, _session);

  @override
  Future<ReadAloudStart> speak(
    ReadAloudRequest request,
    ReadAloudSession session,
  ) async {
    if (!session.isCurrent) return ReadAloudStart.cancelled;
    _loaded = false;
    _paused = false;
    _session?.cancel();
    _pending?.cancel();
    final cancellation = HttpTtsCancellation();
    _pending = cancellation;
    _session = session;
    _textLength = request.text.length;
    final result = await synthesize(request, cancellation);
    if (!session.isCurrent || result is HttpTtsCancelled) {
      if (result is HttpTtsAudio) await result.lease?.release();
      return ReadAloudStart.cancelled;
    }
    if (result is HttpTtsNoAudio && result.synthesisError != null) {
      // 保留服务器或规则执行的真实原因，交由原协调层显示并处理失败。
      throw result.synthesisError!;
    }
    if (result is! HttpTtsAudio || result.audioPath.trim().isEmpty) {
      return ReadAloudStart.noAudio;
    }
    _audio = result;
    // 本地播放端应用全局播放倍速（源级语速已由合成端处理）。
    try {
      await player.playLocalFile(
        result.audioPath.trim(),
        speed: request.speed,
        tag: session,
      );
    } catch (_) {
      if (identical(_audio, result)) {
        _audio = null;
        await result.lease?.release();
      }
      rethrow;
    }
    if (!session.isCurrent) return ReadAloudStart.cancelled;
    _pending = null;
    _loaded = player.isInitialized && identical(player.currentTag, session);
    return _loaded ? ReadAloudStart.started : ReadAloudStart.cancelled;
  }

  /// 由共享播放器的原回调分发；音频书标签和旧段会话不会被接受。
  void handleCompleted(Object? tag) {
    if (identical(tag, _session)) _session?.complete();
  }

  void handleError(Object error, Object? tag) {
    if (!identical(tag, _session)) return;
    _loaded = false;
    _session?.fail(error);
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
  Future<void> pause() {
    if (_playlist?.active == true) return _playlist!.pause();
    final session = _session;
    final ready =
        _loaded &&
        session != null &&
        player.isInitialized &&
        identical(player.currentTag, session);
    session?.cancel();
    _pending?.cancel();
    _pending = null;
    if (!ready) return _pauseBarrier = stop();
    _paused = true;
    return _pauseBarrier = player.pause().catchError((Object error) {
      if (identical(_session, session)) _paused = false;
      throw error;
    });
  }

  @override
  Future<void> stop({Future<void>? playbackStopped}) {
    if (_playlist?.active == true) {
      return _playlist!.stop(playbackStopped: playbackStopped);
    }
    _pauseBarrier = Future.value();
    _loaded = false;
    _paused = false;
    _pending?.cancel();
    _pending = null;
    _session?.cancel();
    _session = null;
    final audio = _audio;
    _audio = null;
    return (playbackStopped ?? player.stop()).whenComplete(() async {
      await audio?.lease?.release();
    });
  }

  @override
  Future<ReadAloudStart> resume(ReadAloudSession session) async {
    if (_playlist?.active == true) return _playlist!.resume(session);
    final previous = _session;
    await _pauseBarrier;
    if (!session.isCurrent ||
        previous == null ||
        !identical(previous, _session) ||
        !canResume) {
      return ReadAloudStart.cancelled;
    }
    _session = session;
    _paused = false;
    final resumed = await player.resumeWithTag(
      previousTag: previous,
      tag: session,
    );
    return resumed && session.isCurrent
        ? ReadAloudStart.started
        : ReadAloudStart.cancelled;
  }
}
