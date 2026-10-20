import '../bridge/rust_errors.dart';

import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/audio_book_service.dart';
import '../../domain/models/audio_media.dart';
import '../../models/book.dart';
import '../bridge/rust_json_decode.dart';
import '../bridge/media_dto_mapping.dart';

/// 音频取址、进度与播放模式的薄适配。— Codex + Bridge
final class RustAudioBookService implements AudioBookService {
  const RustAudioBookService();
  @override
  Future<AudioChapterMedia> getAudioChapterMedia(
    String bookUrl,
    int chapterIndex,
  ) async {
    return audioChapterMediaFromDto(
      await rustFuture(
        () => bridge.audioGetChapterMedia(
          bookUrl: bookUrl,
          chapterIndex: chapterIndex,
        ),
        operation: 'audioGetChapterMedia',
      ),
    );
  }

  @override
  Future<int> getAudioProgress(String bookUrl, int chapterIndex) async =>
      (await rustFuture(
        () => bridge.audioGetProgress(
          bookUrl: bookUrl,
          chapterIndex: chapterIndex,
        ),
        operation: 'audioGetProgress',
      )).toInt();
  @override
  Future<void> saveAudioProgress(
    String bookUrl,
    int chapterIndex,
    int positionMs,
  ) async {
    await rustFuture(
      () => bridge.audioSaveProgress(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
        position: positionMs,
      ),
      operation: 'audioSaveProgress',
    );
  }

  @override
  Future<ReadConfig> audioWithPlayMode({
    ReadConfig? readConfig,
    required int playMode,
  }) async => ReadConfig.fromJson(
    decodeRustJsonMap(
      await rustFuture(
        () => bridge.audioWithPlayMode(
          readConfig: readConfig == null
              ? null
              : jsonEncode(readConfig.toJson()),
          playMode: playMode,
        ),
        operation: 'audioWithPlayMode',
      ),
      'audioWithPlayMode',
    ),
  );
}
