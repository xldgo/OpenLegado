import 'dart:convert';

import 'package:flutter_legado/src/data/repositories/mock_read_aloud_voice_repository.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';

import '../mocks/mocks.dart';

class _Cache extends Fake implements TtsCacheRepository {
  final records = <TtsCacheContext>[];
  final clears = <({int? before, String? book, int? chapter})>[];
  @override
  bool get supportsAudioFiles => true;
  @override
  Future<void> record(String path, TtsCacheContext context) async {
    records.add(context);
  }

  @override
  Future<TtsCacheClearResult> clear({
    String? name,
    int? beforeTimestampMs,
    String? keepBookUrl,
    int? keepChapterIndex,
  }) async {
    clears.add((
      before: beforeTimestampMs,
      book: keepBookUrl,
      chapter: keepChapterIndex,
    ));
    return const TtsCacheClearResult();
  }
}

class _Api extends MockRustApi {
  final _Cache cache = _Cache();
  final voices = MockReadAloudVoiceRepository();
  @override
  MockReadAloudVoiceRepository get readAloudVoiceRepository => voices;
  @override
  _Cache get ttsCacheRepository => cache;
}

class _Synth extends Fake implements HttpTtsSynthesizer {
  final inputs = <String>[];
  final voiceInputs = <({String? tone, String? speaker, String? emotion})>[];
  final cache = <String>{};
  int active = 0, peak = 0;
  Completer<void>? block;
  final cancellations = <HttpTtsCancellation>[];
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required int engineId,
    required String text,
    String? engineUrl,
    double speed = 1,
    double pitch = 1,
    double volume = 1,
    String? voiceName,
    String? toneId,
    String? speakerName,
    String? emotionTag,
    HttpTtsCancellation? cancellation,
  }) async {
    inputs.add(text);
    voiceInputs.add((tone: toneId, speaker: speakerName, emotion: emotionTag));
    cancellations.add(cancellation!);
    active++;
    if (active > peak) peak = active;
    try {
      if (block != null && text != '当前段。') {
        final wake = Completer<void>();
        void cancel() {
          if (!wake.isCompleted) wake.complete();
        }

        cancellation.addListener(cancel);
        await Future.any([block!.future, wake.future]);
        cancellation.removeListener(cancel);
      }
      if (cancellation.isCancelled) return const HttpTtsCancelled();
      final hit = cache.contains(text);
      cache.add(text);
      return HttpTtsAudio(
        audioPath: '/cache/tts_${text.hashCode}.wav',
        fromCache: hit,
      );
    } finally {
      active--;
    }
  }
}

Future<void> flush() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerFallbacks);
  late _Api api;
  late _Synth synthesis;
  late FakeStreamAudioPlayer player;
  late ProviderContainer container;
  AudioNotifier notifier() => container.read(audioNotifierProvider.notifier);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = _Api();
    synthesis = _Synth();
    player = FakeStreamAudioPlayer();
    when(() => api.configRepository.getConfig(any())).thenAnswer(
      (call) async =>
          call.positionalArguments[0] == 'audioPreDownloadNum' ? '1' : null,
    );
    when(() => api.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => api.readingRepository.getChapters(any())).thenAnswer(
      (_) async => const [
        BookChapter(title: '第一章', index: 0),
        BookChapter(title: '第二章', index: 1),
        BookChapter(title: '第三章', index: 2),
      ],
    );
    when(() => api.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer(
          (call) async => [
            '当前段。\n后续段一。\n后续段二。',
            '下一章段一。\n下一章段二。',
            '窗口外。',
          ][call.positionalArguments[1] as int],
        );
    when(() => api.httpTtsRepository.getHttpTts()).thenAnswer(
      (_) async => const [
        HttpTts(id: 1, name: '源', url: 'https://tts', synthesisThreadCount: 2),
      ],
    );
    container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWithValue(api),
        httpTtsSynthesizerProvider.overrideWithValue(synthesis),
        streamAudioPlayerProvider.overrideWithValue(player),
      ],
    );
    addTearDown(container.dispose);
  });
  Future<void> start() async {
    await notifier().loadChapters('book');
    notifier().updateConfig(engineId: 1, engineUrl: 'https://tts');
    await notifier().play();
  }

  test('当前段起播后预合成剩余段与设定后续章，源并发上限生效且不提前播放', () async {
    await start();
    await flush();
    expect(synthesis.inputs, ['当前段。', '后续段一。', '后续段二。', '下一章段一。', '下一章段二。']);
    expect(synthesis.peak, lessThanOrEqualTo(2));
    expect(player.playedLocalFiles, hasLength(1));
    expect(api.ttsCacheRepository.records.map((c) => c.chapterIndex), [
      0,
      0,
      0,
      1,
      1,
    ]);
    verifyNever(() => api.readingRepository.getChapterContentFull('book', 2));
    player.completePlayback();
    await flush();
    expect(notifier().currentParagraphIndex, 1);
    expect(player.playedLocalFiles, hasLength(2));
    expect(synthesis.cache.contains('后续段一。'), isTrue);
  });
  test('停止取消预合成，不加载窗口外章节，保留模式清理保护当前章', () async {
    synthesis.block = Completer<void>();
    await start();
    await flush();
    expect(synthesis.active, 2);
    notifier().stop();
    await flush();
    expect(synthesis.active, 0);
    expect(synthesis.cancellations.skip(1).every((c) => c.isCancelled), isTrue);
    expect(player.playedLocalFiles, hasLength(1));
    verifyNever(() => api.readingRepository.getChapterContentFull('book', 1));
    expect(api.ttsCacheRepository.clears.last.book, 'book');
    expect(api.ttsCacheRepository.clears.last.chapter, 0);
    expect(api.ttsCacheRepository.clears.last.before, isNotNull);
  });
  test('保留时间零启动和停止清扫缓存，停止后不保护旧章节', () async {
    when(() => api.configRepository.getConfig('audioCacheCleanTime'))
        .thenAnswer((_) async => '0');
    await start();
    await flush();
    expect(api.ttsCacheRepository.clears.first.before, isNull);
    notifier().stop();
    await flush();
    final last = api.ttsCacheRepository.clears.last;
    expect(last.before, isNull);
    expect(last.book, isNull);
    expect(last.chapter, isNull);
  });
  test('换书入口立即取消旧预合成，旧正文请求不继续扩展窗口', () async {
    synthesis.block = Completer<void>();
    await start();
    await flush();
    await notifier().loadChapters('other-book');
    await flush();
    expect(synthesis.active, 0);
    expect(synthesis.cancellations.skip(1).every((c) => c.isCancelled), isTrue);
    verifyNever(() => api.readingRepository.getChapterContentFull('book', 1));
  });
  test('音色及情感恢复后进入当前与预合成请求，禁用后不改选其他音色', () async {
    api.voices.importHttp(1, {
      'speakersJson': '[{"name":"中文女声","toneID":"zh-a"}]',
      'emotionsJson': '[{"name":"高兴","tag":"happy"}]',
    });
    final voice = (await api.voices.list()).single;
    when(() => api.configRepository.getConfig('ttsVoice:${1}')).thenAnswer(
      (_) async => jsonEncode({'voiceId': voice.id, 'emotionTag': 'happy'}),
    );
    await start();
    await flush();
    expect(synthesis.voiceInputs, hasLength(5));
    expect(
      synthesis.voiceInputs.every(
        (v) => v.tone == 'zh-a' && v.speaker == '中文女声' && v.emotion == 'happy',
      ),
      isTrue,
    );
    await api.voices.setFlags(voice.id, enabled: false, excluded: false);
    await notifier().restartCurrentTts();
    await flush();
    expect(synthesis.voiceInputs.last.tone, isNull);
    expect(
      container.read(audioNotifierProvider).errorMessage,
      contains('所选音色不可用'),
    );
  });
  test('保存选择按引擎隔离，非法情感不写入，恢复默认明确清空', () async {
    api.voices.importHttp(2, {
      'speakersJson': '[{"name":"中文","toneID":"a"}]',
      'emotionsJson': '[{"name":"高兴","tag":"happy"}]',
    });
    final voice = (await api.voices.list()).single;
    final writes = <String, String>{};
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((call) async {
          writes[call.positionalArguments[0] as String] =
              call.positionalArguments[1] as String;
        });
    await notifier().setHttpTtsVoice(2, voice, emotionTag: 'happy');
    expect(jsonDecode(writes['ttsVoice:2']!)['voiceId'], voice.id);
    expect(writes.containsKey('ttsVoice:1'), false);
    await expectLater(
      notifier().setHttpTtsVoice(2, voice, emotionTag: 'sad'),
      throwsStateError,
    );
    expect(jsonDecode(writes['ttsVoice:2']!)['emotionTag'], 'happy');
    await notifier().setHttpTtsVoice(2, null);
    expect(writes['ttsVoice:2'], '');
  });
}
