/// 平台媒体控制只传递会话身份和毫秒位置，不引用页面或播放器。— Codex + Bridge
final class MediaPlaybackTarget {
  const MediaPlaybackTarget({
    required this.mediaId,
    required this.sessionToken,
    required this.chapterIndex,
  });
  final String mediaId;
  final int sessionToken, chapterIndex;

  static MediaPlaybackTarget? parse(Object? value) {
    if (value is! Map) return null;
    final id = value['mediaId'],
        token = value['sessionToken'],
        chapter = value['chapterIndex'];
    if (id is! String ||
        id.isEmpty ||
        token is! int ||
        token < 1 ||
        chapter is! int ||
        chapter < 0) {
      return null;
    }
    return MediaPlaybackTarget(
      mediaId: id,
      sessionToken: token,
      chapterIndex: chapter,
    );
  }
}

final class MediaSeekRequest {
  const MediaSeekRequest({required this.target, required this.position});
  final MediaPlaybackTarget target;
  final int position;

  static MediaSeekRequest? parse(Object? value) {
    final target = MediaPlaybackTarget.parse(value);
    if (target == null ||
        value is! Map ||
        value['position'] is! int ||
        (value['position'] as int) < 0) {
      return null;
    }
    return MediaSeekRequest(target: target, position: value['position'] as int);
  }
}

final class MediaPlaybackProgress {
  const MediaPlaybackProgress({
    required this.mediaId,
    required this.sessionToken,
    required this.chapterIndex,
    required this.state,
    required this.position,
    required this.duration,
    required this.speed,
    required this.canSeek,
    required this.hasPrevious,
    required this.hasNext,
    required this.isStream,
  });
  final String mediaId, state;
  final int sessionToken, chapterIndex, position, duration;
  final double speed;
  final bool canSeek, hasPrevious, hasNext, isStream;

  Map<String, Object> toMap() => {
    'mediaId': mediaId,
    'sessionToken': sessionToken,
    'chapterIndex': chapterIndex,
    'state': state,
    'position': position,
    'duration': duration,
    'speed': speed,
    'canSeek': canSeek,
    'hasPrevious': hasPrevious,
    'hasNext': hasNext,
    'isStream': isStream,
  };
}
