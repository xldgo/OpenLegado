import '../../domain/contracts/audio_book_service.dart';
import '../../domain/contracts/reading_repository.dart';
import '../../domain/models/audio_media.dart';
import '../../domain/models/audio_skip_window.dart';
import '../../models/book.dart';

/// 音频Mock复用原目录，进度仍保留原0/空写示例。— Codex + Bridge
final class MockAudioBookService implements AudioBookService {
  const MockAudioBookService({required this._reading});
  final ReadingRepository _reading;
  @override
  Future<AudioChapterMedia> getAudioChapterMedia(
    String bookUrl,
    int chapterIndex,
  ) async {
    final chapters = await _reading.getChapters(bookUrl);
    if (chapterIndex < 0 || chapterIndex >= chapters.length) {
      throw RangeError.index(chapterIndex, chapters);
    }
    final chapter = chapters[chapterIndex];
    final mediaUrl = chapter.isVolume
        ? ''
        : ((chapter.resourceUrl?.trim().isNotEmpty ?? false)
              ? chapter.resourceUrl!.trim()
              : chapter.url.trim());
    return AudioChapterMedia(
      chapterIndex: chapterIndex,
      title: chapter.title,
      mediaUrl: mediaUrl,
      url: chapter.url,
      resourceUrl: chapter.resourceUrl,
      isVolume: chapter.isVolume,
    );
  }

  @override
  Future<int> getAudioProgress(String bookUrl, int chapterIndex) async => 0;
  @override
  Future<void> saveAudioProgress(
    String bookUrl,
    int chapterIndex,
    int positionMs,
  ) async {}
  @override
  Future<AudioSkipWindow?> resolveSkipWindow({
    required ReadConfig? readConfig,
    required int durationMs,
    required int globalOpenCredits,
    required int globalCloseCredits,
  }) async => null;

  @override
  Future<ReadConfig> audioWithPlayMode({
    ReadConfig? readConfig,
    required int playMode,
  }) async => (readConfig ?? const ReadConfig()).copyWith(playMode: playMode);
}
