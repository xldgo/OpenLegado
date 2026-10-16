import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/contracts/audio_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_selection_repository.dart';
import 'package:flutter_legado/src/domain/models/http_tts_voice_selection.dart';
import 'package:flutter_legado/src/features/audio/services/audio_book_preferences_service.dart';
import 'package:flutter_legado/src/features/audio/services/audio_preferences_host.dart';
import 'package:flutter_legado/src/features/read_aloud/services/read_aloud_selection_service.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/audio/audio_state.dart';

class PreferencesBookshelf extends Fake implements BookshelfRepository {
  final books = <String, Book>{};
  final reads = <String>[];
  final writes = <Book>[];
  Future<void>? saveBarrier;
  Object? readError, saveError;
  @override
  Future<Book?> getBook(String url) async {
    reads.add(url);
    if (readError != null) throw readError!;
    return books[url];
  }

  @override
  Future<void> updateBook(Book book) async {
    await saveBarrier;
    if (saveError != null) throw saveError!;
    writes.add(book);
    books[book.bookUrl] = book;
  }
}

class PreferencesAudioBook extends Fake implements AudioBookService {
  final modes = <int>[];
  @override
  Future<ReadConfig> audioWithPlayMode({
    ReadConfig? readConfig,
    required int playMode,
  }) async {
    modes.add(playMode);
    return (readConfig ?? const ReadConfig()).copyWith(playMode: playMode);
  }
}

class PreferencesHttp extends Fake implements HttpTtsRepository {
  List<HttpTts> engines = const [];
  Object? readError;
  @override
  Future<List<HttpTts>> getHttpTts() async {
    if (readError != null) throw readError!;
    return engines;
  }
}

class PreferencesSelections extends Fake
    implements ReadAloudSelectionRepository {
  String? engineUrl;
  int? engineId;
  Future<void>? readBarrier;
  Object? saveError;
  final engineWrites = <({String url, int? id})>[];
  final cloudVoices = <String, String?>{};
  final httpVoices = <int, HttpTtsVoiceSelection?>{};
  @override
  Future<String?> getEngineUrl() async => engineUrl;
  @override
  Future<int?> getHttpEngineId() async {
    await readBarrier;
    return engineId;
  }

  @override
  Future<void> setEngine(String url, {int? httpEngineId}) async {
    if (saveError != null) throw saveError!;
    engineWrites.add((url: url, id: httpEngineId));
    engineUrl = url;
    engineId = httpEngineId;
  }

  @override
  Future<void> setCloudVoice(String engineId, String? voiceId) async =>
      cloudVoices[engineId] = voiceId;
  @override
  Future<void> setHttpVoice(
    int engineId,
    HttpTtsVoiceSelection? selection,
  ) async => httpVoices[engineId] = selection;
}

/// 独立服务共用唯一宿主书籍和配置，不创建ProviderContainer或播放器。— Codex + UI
class AudioPreferencesFixture {
  AudioPreferencesFixture() {
    final host = AudioPreferencesHost(
      readState: () {
        _check();
        return state;
      },
      writeState: (value) {
        _check();
        state = value;
      },
      readBook: () {
        _check();
        return book;
      },
      writeBook: (value) {
        _check();
        book = value;
      },
      currentToken: () => token,
      isDisposed: () => disposed,
      updateConfig:
          ({
            String? engineUrl,
            int? engineId,
            double? speed,
            bool restartPlayback = true,
            bool persistBookSpeed = true,
          }) {
            _check();
            final old = state.config;
            state = state.copyWith(
              config: TtsConfig(
                engineUrl: engineUrl ?? old.engineUrl,
                engineId: engineId ?? (engineUrl != null ? null : old.engineId),
                speed: speed ?? old.speed,
                voiceName: old.voiceName,
                pitch: old.pitch,
                volume: old.volume,
              ),
            );
            configApplications++;
            if (speed != null && persistBookSpeed) {
              preferences.scheduleSpeed(speed);
            }
          },
      restartReadAloud: () async {
        _check();
        restarts++;
      },
    );
    preferences = AudioBookPreferencesService(
      host: host,
      bookshelf: bookshelf,
      audioBook: audioBook,
    );
    selection = ReadAloudSelectionService(
      host: host,
      preferences: preferences,
      httpTts: http,
      selections: selections,
    );
  }

  final bookshelf = PreferencesBookshelf();
  final audioBook = PreferencesAudioBook();
  final http = PreferencesHttp();
  final selections = PreferencesSelections();
  late final AudioBookPreferencesService preferences;
  late final ReadAloudSelectionService selection;
  AudioState state = AudioState(config: TtsConfig());
  Book? book;
  int token = 1, restarts = 0, configApplications = 0;
  bool disposed = false;
  void _check() {
    if (disposed) throw StateError('销毁后访问宿主');
  }

  void bind(Book value) {
    book = value;
    bookshelf.books[value.bookUrl] = value;
    state = state.copyWith(bookUrl: value.bookUrl);
    token++;
  }

  void close() {
    preferences.dispose();
    disposed = true;
  }
}
