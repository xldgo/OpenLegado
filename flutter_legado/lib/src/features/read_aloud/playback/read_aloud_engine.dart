import '../../../domain/contracts/tts_cache_repository.dart';

/// 一段朗读的不可变输入，不携带书籍、章节或持久化状态。— Codex + UI
final class ReadAloudRequest {
  const ReadAloudRequest({
    required this.text,
    this.engineId = 0,
    this.engineUrl = '',
    this.speed = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.voiceName,
    this.voicePresetId,
    this.cloudVoiceOptions,
    this.toneId,
    this.speakerName,
    this.emotionTag,
    this.cacheContext,
    this.sourceVersion,
  });

  final String text;
  final int engineId;
  final String engineUrl;
  final double speed;
  final double pitch;
  final double volume;
  final String? voiceName;
  final String? voicePresetId;
  final Map<String, dynamic>? cloudVoiceOptions;
  final String? toneId;
  final String? speakerName;
  final String? emotionTag;
  final TtsCacheContext? cacheContext;
  final String? sourceVersion;
  ReadAloudRequest copyWith({
    String? text,
    double? speed,
    TtsCacheContext? cacheContext,
  }) => ReadAloudRequest(
    text: text ?? this.text,
    engineId: engineId,
    engineUrl: engineUrl,
    speed: speed ?? this.speed,
    pitch: pitch,
    volume: volume,
    voiceName: voiceName,
    voicePresetId: voicePresetId,
    cloudVoiceOptions: cloudVoiceOptions,
    toneId: toneId,
    speakerName: speakerName,
    emotionTag: emotionTag,
    cacheContext: cacheContext ?? this.cacheContext,
    sourceVersion: sourceVersion,
  );
}

/// 起播结果与自然完成分开；无音频由原播放协调层决定如何提示和推进。
enum ReadAloudStart { started, noAudio, cancelled }

/// 引擎只负责一段的播放与控制；段落由ReadAloudController协调，媒体会话由宿主拥有。
abstract interface class ReadAloudEngine {
  bool get canResume;
  Future<ReadAloudStart> speak(
    ReadAloudRequest request,
    ReadAloudSession session,
  );
  Future<ReadAloudStart> resume(ReadAloudSession session);
  Future<void> pause();
  Future<void> stop();
}

/// 统一回调归属，复用协调层的有效性判定，不另建播放代数。
///
/// 偏移相对本次请求的文本，单位为 UTF-16；原文章节映射由上层完成。
/// 终止标志只记录本段回调已消费，不能作为书籍或章节播放状态。
final class ReadAloudSession {
  ReadAloudSession({
    required this._isCurrent,
    required this._onCompleted,
    required this._onProgress,
    required this._onError,
  });

  final bool Function() _isCurrent;
  final void Function() _onCompleted;
  final void Function(int offset) _onProgress;
  final void Function(Object error) _onError;
  bool _ended = false;

  bool get isCurrent => !_ended && _isCurrent();

  void reportProgress(int offset) {
    if (isCurrent) _onProgress(offset);
  }

  void complete() {
    if (!isCurrent) return;
    _ended = true;
    _onCompleted();
  }

  void fail(Object error) {
    if (!isCurrent) return;
    _ended = true;
    _onError(error);
  }

  void cancel() => _ended = true;
}

/// 播放文件的原文映射；一个逻辑段落可包含多个云端长度分片。— Codex + UI
final class ReadAloudPlaylistCue {
  const ReadAloudPlaylistCue({
    required this.request,
    required this.sourceOffset,
    required this.paragraphIndex,
  });
  final ReadAloudRequest request;
  final int sourceOffset, paragraphIndex;
}

/// 文件引擎的可选能力，系统直接朗读不实现此接口。
abstract interface class ReadAloudPlaylistEngine {
  bool get supportsPlaylist;
  Future<ReadAloudStart> speakPlaylist(
    List<ReadAloudPlaylistCue> cues,
    ReadAloudSession session, {
    required void Function(ReadAloudPlaylistCue cue) onCueStarted,
  });
}
