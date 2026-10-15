/// 音频队列只拥有本地文件及回调身份，不保存书章、原文位置或缓存租约。— Codex + UI
final class AudioPlaylistItem {
  const AudioPlaylistItem({required this.path, required this.tag});
  final String path;
  final Object tag;
}

/// 当前文件与有限后续项交给同一原生播放器；调用方负责队列窗口和生命周期。
abstract interface class AudioPlaylistPlayer {
  Object? get currentPlaylistTag;
  bool get playlistFinished;
  Future<void> startPlaylist(
    AudioPlaylistItem first, {
    required double speed,
    required void Function(Object tag) onStarted,
    required void Function(Object tag) onCompleted,
    required void Function(Duration position, Duration duration, Object tag)
    onProgress,
    required void Function(Object error) onError,
  });
  Future<void> appendPlaylist(AudioPlaylistItem item);
  Future<void> discardPlayedItems();
}
