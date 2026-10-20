import 'package:audio_service/audio_service.dart';

import '../../services/media_session_models.dart';

/// 系统媒体适配器只转发命令和发布快照，不持有播放器或业务队列。— Codex + UI
final class ReadAloudAudioHandler extends BaseAudioHandler {
  ReadAloudAudioHandler({
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
    required this.onOpen,
  });

  final void Function() onPlay, onPause, onStop, onNext, onPrevious;
  final void Function(MediaSeekRequest) onSeek;
  final void Function(MediaPlaybackTarget) onOpen;
  MediaPlaybackTarget? _target;
  bool _canSeek = false, _hasNext = false, _hasPrevious = false;

  bool owns(String id, int token) =>
      mediaItem.value?.id == id &&
      mediaItem.value?.extras?['sessionToken'] == token;

  void publishMetadata({
    required String title,
    required String artist,
    required String album,
    required String mediaId,
    required int sessionToken,
    required String timerText,
  }) {
    final old = mediaItem.value;
    final sameIdentity = owns(mediaId, sessionToken);
    final sameChapter =
        sameIdentity &&
        old?.artist == artist &&
        old?.title == (title.isEmpty ? artist : title);
    if (!sameChapter) {
      _target = null;
      _canSeek = _hasNext = _hasPrevious = false;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [],
          systemActions: {},
          processingState: AudioProcessingState.loading,
          updatePosition: Duration.zero,
        ),
      );
    }
    mediaItem.add(
      MediaItem(
        id: mediaId,
        title: title.isEmpty ? artist : title,
        artist: artist,
        album: album,
        displayTitle: title.isEmpty ? artist : title,
        displaySubtitle: title.isEmpty ? '' : artist,
        displayDescription: timerText,
        artUri: sameIdentity ? old?.artUri : null,
        duration: sameChapter ? old?.duration : null,
        extras: {
          'sessionToken': sessionToken,
          if (sameChapter && _target != null)
            'chapterIndex': _target!.chapterIndex,
        },
      ),
    );
  }

  void publishArtwork(String id, int token, Uri? uri) {
    if (owns(id, token)) mediaItem.add(mediaItem.value!.copyWith(artUri: uri));
  }

  void publishProgress(MediaPlaybackProgress progress) {
    if (!owns(progress.mediaId, progress.sessionToken)) return;
    _target = MediaPlaybackTarget(
      mediaId: progress.mediaId,
      sessionToken: progress.sessionToken,
      chapterIndex: progress.chapterIndex,
    );
    _canSeek = progress.canSeek && progress.duration > 0;
    _hasPrevious = progress.hasPrevious;
    _hasNext = progress.hasNext;
    final duration = Duration(
      milliseconds: progress.duration < 0 ? 0 : progress.duration,
    );
    final item = mediaItem.value!;
    if (item.duration != duration ||
        item.extras?['chapterIndex'] != progress.chapterIndex) {
      mediaItem.add(
        item.copyWith(
          duration: duration,
          extras: {
            'sessionToken': progress.sessionToken,
            'chapterIndex': progress.chapterIndex,
          },
        ),
      );
    }
    final playing = progress.state == 'playing';
    final controls = [
      if (_hasPrevious) MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      if (_hasNext) MediaControl.skipToNext,
      MediaControl.stop,
    ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        androidCompactActionIndices: List.generate(
          controls.length - 1,
          (i) => i,
        ),
        systemActions: {if (_canSeek) MediaAction.seek},
        processingState: progress.state == 'buffering'
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: playing,
        updatePosition: Duration(
          milliseconds: progress.position.clamp(
            0,
            progress.duration > 0 ? progress.duration : 0,
          ),
        ),
        bufferedPosition: Duration(
          milliseconds: progress.position.clamp(0, duration.inMilliseconds),
        ),
        speed: progress.speed,
      ),
    );
  }

  /// 便捷播放态不把已建立的时间轴或倍率重置到默认值。
  void publishState(String state) {
    if (state == 'stopped') {
      clear();
      return;
    }
    if (_target == null) return;
    final current = playbackState.value;
    final playing = state == 'playing';
    final controls = [
      if (_hasPrevious) MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      if (_hasNext) MediaControl.skipToNext,
      MediaControl.stop,
    ];
    playbackState.add(
      current.copyWith(
        controls: controls,
        androidCompactActionIndices: List.generate(
          controls.length - 1,
          (i) => i,
        ),
        playing: playing,
        processingState: state == 'buffering'
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        updatePosition: current.position,
      ),
    );
  }

  void clear() {
    _target = null;
    _canSeek = _hasNext = _hasPrevious = false;
    playbackState.add(PlaybackState());
    mediaItem.add(null);
  }

  void openCurrent() {
    final target = _target;
    if (target != null) onOpen(target);
  }

  @override
  Future<void> play() async {
    if (_target != null) onPlay();
  }

  @override
  Future<void> pause() async {
    if (_target != null) onPause();
  }

  @override
  Future<void> stop() async {
    if (_target != null) onStop();
  }

  @override
  Future<void> skipToNext() async {
    if (_target != null && _hasNext) onNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_target != null && _hasPrevious) onPrevious();
  }

  @override
  Future<void> seek(Duration position) async {
    final target = _target;
    if (target == null || !_canSeek || position < Duration.zero) return;
    final duration = mediaItem.value?.duration ?? Duration.zero;
    onSeek(
      MediaSeekRequest(
        target: target,
        position: position.inMilliseconds.clamp(0, duration.inMilliseconds),
      ),
    );
  }

  @override
  Future<void> onNotificationDeleted() => stop();
  // 划掉 Activity 任务不等于停止音频；服务与共享 FlutterEngine 继续持有播放。
  @override
  Future<void> onTaskRemoved() async {}
}
