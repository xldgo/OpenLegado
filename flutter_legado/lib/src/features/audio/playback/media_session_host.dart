import '../../../models/book.dart';
import '../application/audio_state.dart';
import '../application/read_aloud_position.dart';

/// 系统媒体操作使用现有播放状态与命令，不持有Ref或Notifier。— Codex + UI
final class MediaSessionHost {
  const MediaSessionHost({
    required this.readState,
    required this.writeState,
    required this.currentToken,
    required this.isDisposed,
    required this.currentBook,
    required this.isBookHidden,
    required this.timerLabel,
    required this.readPosition,
    required this.hasReadAloudUnits,
    required this.paragraphIndex,
    required this.paragraphCount,
    required this.loadPreferences,
    required this.mediaButtonPerChapter,
    required this.resumeOrPlay,
    required this.pause,
    required this.stop,
    required this.nextChapter,
    required this.previousChapter,
    required this.nextParagraph,
    required this.previousParagraph,
    required this.seekReadAloud,
    required this.persistStreamPosition,
  });

  final AudioState Function() readState;
  final void Function(AudioState) writeState;
  final int Function() currentToken;
  final bool Function() isDisposed;
  final Book? Function() currentBook;
  final bool Function(Book) isBookHidden;
  final String Function() timerLabel;
  final ReadAloudPosition? Function() readPosition;
  final bool Function() hasReadAloudUnits;
  final int Function() paragraphIndex;
  final int Function() paragraphCount;
  final Future<void> Function() loadPreferences;
  final bool Function() mediaButtonPerChapter;
  final Future<void> Function({bool userInitiated}) resumeOrPlay;
  final void Function({bool dueToInterruption}) pause;
  final void Function() stop;
  final Future<void> Function() nextChapter;
  final Future<void> Function() previousChapter;
  final Future<void> Function() nextParagraph;
  final Future<void> Function() previousParagraph;
  final Future<void> Function(int chapterIndex, int offset) seekReadAloud;
  final Future<void> Function({bool force, int? positionMs})
  persistStreamPosition;
}
