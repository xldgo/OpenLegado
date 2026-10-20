import '../../models/book.dart';
import '../models/audio_media.dart';

/// 音频取址与持久化，不接管播放器和媒体会话生命周期。— Codex + Bridge
abstract interface class AudioBookService {
  Future<AudioChapterMedia> getAudioChapterMedia(
    String bookUrl,
    int chapterIndex,
  );
  Future<int> getAudioProgress(String bookUrl, int chapterIndex);
  Future<void> saveAudioProgress(
    String bookUrl,
    int chapterIndex,
    int positionMs,
  );
  Future<ReadConfig> audioWithPlayMode({
    ReadConfig? readConfig,
    required int playMode,
  });
}
