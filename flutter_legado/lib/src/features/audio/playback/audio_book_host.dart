import '../../../models/book.dart';
import '../application/audio_state.dart';

/// 音频书复用宿主的播放状态、标识和章级动作，不持有Ref。— Codex + UI
final class AudioBookHost {
  const AudioBookHost({
    required this.readState,
    required this.writeState,
    required this.currentToken,
    required this.advanceToken,
    required this.isDisposed,
    required this.boundBook,
    required this.stopSystemTts,
    required this.activateMedia,
    required this.consumeChapterStop,
    required this.nextChapter,
    required this.replay,
    required this.pause,
    required this.stop,
  });

  final AudioState Function() readState;
  final void Function(AudioState) writeState;
  final int Function() currentToken;
  final int Function() advanceToken;
  final bool Function() isDisposed;
  final Book? Function() boundBook;
  final Future<void> Function() stopSystemTts;
  final Future<void> Function() activateMedia;
  final bool Function() consumeChapterStop;
  final Future<void> Function() nextChapter;
  final Future<void> Function() replay;
  final void Function() pause;
  final void Function() stop;
}
