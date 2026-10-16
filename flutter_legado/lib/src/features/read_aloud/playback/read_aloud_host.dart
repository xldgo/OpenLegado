import '../../../providers/audio/audio_state.dart';

/// 朗读与应用播放协调层之间的端口，不暴露Ref或Notifier。— Codex + UI
final class ReadAloudHost {
  const ReadAloudHost({
    required this.readState,
    required this.writeState,
    required this.currentToken,
    required this.advanceToken,
    required this.isDisposed,
    required this.resolveEngineUrl,
    required this.resolveEngineId,
    required this.changed,
    required this.activateMedia,
    required this.publishProgress,
    required this.reviseTimeline,
    required this.consumeChapterStop,
    required this.nextChapter,
    required this.previousChapter,
    required this.pause,
    required this.stop,
    required this.notifyPaused,
  });

  final AudioState Function() readState;
  final void Function(AudioState) writeState;
  final int Function() currentToken;
  final int Function() advanceToken;
  final bool Function() isDisposed;
  final String Function() resolveEngineUrl;
  final Future<int?> Function() resolveEngineId;
  final void Function() changed;
  final Future<void> Function() activateMedia;
  final Future<void> Function({bool force}) publishProgress;
  final void Function() reviseTimeline;
  final bool Function() consumeChapterStop;
  final Future<void> Function() nextChapter;
  final Future<void> Function() previousChapter;
  final void Function() pause;
  final void Function() stop;
  final Future<void> Function() notifyPaused;
}
