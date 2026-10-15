/// 正文朗读、音频书及独立试听共用的纯音频契约。— Codex + UI
/// 播放器只管理媒体和回调身份，书章、焦点和定时由既有协调层负责。
abstract class StreamAudioPlayer {
  Object? get currentTag;
  bool get isInitialized;
  bool get isPlaying;
  Duration get position;
  Duration get duration;
  String? get currentUrl;

  void Function(Object? tag)? onCompleted;
  void Function(Duration position, Duration duration, Object? tag)? onProgress;
  void Function(Object error, Object? tag)? onError;

  Future<void> playUrl(String url, {double speed = 1, Object? tag});
  Future<void> playLocalFile(String path, {double speed = 1, Object? tag});
  Future<bool> resumeWithTag({
    required Object previousTag,
    required Object tag,
  });
  Future<void> pause();
  Future<void> resume();
  Future<void> setSpeed(double speed);
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}
