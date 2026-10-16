import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_providers.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_legado/src/providers/providers.dart';

import '../mocks/mocks.dart';
import '../fixtures/playlist_audio_player.dart';

class _Cache extends Fake implements TtsCacheRepository {
  @override
  bool get supportsAudioFiles => true;
  @override
  Future<void> record(String path, TtsCacheContext context) async {}
  @override
  Future<TtsCacheClearResult> clear({
    String? name,
    int? beforeTimestampMs,
    String? keepBookUrl,
    int? keepChapterIndex,
  }) async => const TtsCacheClearResult();
}

class _Api extends MockRustApi {
  @override
  TtsCacheRepository get ttsCacheRepository => _cache;
  final _cache = _Cache();
}

class _Http extends Fake implements HttpTtsSynthesizer {
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
  }) async => HttpTtsAudio(audioPath: '/cache/${text.hashCode}.wav');
}

class _Cloud extends Fake implements CloudTtsSynthesizer {
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required String engineId,
    required String text,
    String? voiceId,
    Map<String, dynamic>? voiceOptions,
    HttpTtsCancellation? cancellation,
  }) async => HttpTtsAudio(audioPath: '/cache/${text.hashCode}.wav');
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
  late FakePlaylistAudioPlayer player;
  late ProviderContainer container;
  late Map<String, String> config;
  String content = '';
  AudioNotifier notifier() => container.read(audioNotifierProvider.notifier);
  AudioState state() => container.read(audioNotifierProvider);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = _Api();
    player = FakePlaylistAudioPlayer();
    config = {'audioPreDownloadNum': '0'};
    content = '第一段。\n第二段。\n第三段。';
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((c) async => config[c.positionalArguments[0]]);
    when(() => api.configRepository.setConfig(any(), any()))
        .thenAnswer((c) async {
          config[c.positionalArguments[0] as String] =
              c.positionalArguments[1] as String;
        });
    when(() => api.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => null);
    when(() => api.readingRepository.getChapters(any())).thenAnswer(
      (_) async => const [
        BookChapter(title: '一', index: 0),
        BookChapter(title: '二', index: 1),
      ],
    );
    when(() => api.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => content);
    when(() => api.httpTtsRepository.getHttpTts()).thenAnswer(
      (_) async => const [
        HttpTts(
          id: 1,
          name: 'HTTP',
          url: 'https://fixture.test/tts',
          synthesisThreadCount: 2,
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWithValue(api),
        streamAudioPlayerProvider.overrideWithValue(player),
        httpTtsSynthesizerProvider.overrideWithValue(_Http()),
        cloudTtsSynthesizerProvider.overrideWithValue(_Cloud()),
      ],
    );
    addTearDown(() async {
      notifier().stop();
      await flush();
      container.dispose();
    });
  });
  Future<void> start({bool cloud = false}) async {
    if (cloud) {
      await api.cloudTtsRepository.save(
        const CloudTtsEngine(
          id: 'cloud',
          name: '云',
          provider: 'openai_speech',
          credentialKey: 'cloud-tts:cloud:test',
        ),
      );
    }
    await notifier().loadChapters('book');
    notifier().updateConfig(
      engineId: 1,
      engineUrl: cloud ? 'cloud://cloud' : 'https://fixture.test/tts',
    );
    await notifier().play();
    await flush();
  }

  test('HTTP原生自动换项同步段落与原文位置，同章只装载一次，章末才停止', () async {
    await start();
    notifier().startChapterStop(1);
    expect(player.starts, 1);
    expect(player.items, hasLength(3));
    player.advance();
    await flush();
    expect(notifier().currentParagraphIndex, 1);
    expect(notifier().readAloudPosition.value!.offset, content.indexOf('第二'));
    expect(notifier().chaptersToStopRemaining, 1);
    player.advance();
    await flush();
    expect(notifier().currentParagraphIndex, 2);
    player.advance();
    await flush();
    expect(state().state, PlayerState.idle);
    expect(state().currentIndex, 0);
    expect(player.starts, 1);
  });

  test('暂停续播后的自动换项仍推进当前段落，旧回调不能写回', () async {
    await start();
    notifier().startChapterStop(1);
    player.advance();
    await flush();
    notifier().pause();
    await flush();
    expect(state().state, PlayerState.paused);
    await notifier().resumeOrPlay();
    await flush();
    expect(state().state, PlayerState.playing);
    player.report(500);
    expect(
      notifier().readAloudPosition.value!.offset,
      content.indexOf('第二') + 2,
    );
    player.advance();
    await flush();
    expect(notifier().currentParagraphIndex, 2);
    expect(player.starts, 1);
    player.advance();
    await flush();
    expect(state().state, PlayerState.idle);
  });

  test('手动定位清空原生旧队列，迟到换项不覆盖新段落', () async {
    await start();
    final callback = player.started!;
    final oldTag = player.items[1].tag;
    await notifier().seekToParagraph(2);
    await flush();
    expect(player.starts, 2);
    callback(oldTag);
    expect(notifier().currentParagraphIndex, 2);
    expect(notifier().readAloudPosition.value!.offset, content.indexOf('第三'));
  });

  test('云端长度分片共用同一播放队列，片间完成不消费章末', () async {
    content = List.filled(8600, '甲').join();
    await start(cloud: true);
    notifier().startChapterStop(1);
    expect(player.items, hasLength(3));
    player.advance();
    await flush();
    expect(notifier().currentParagraphIndex, 0);
    expect(notifier().readAloudPosition.value!.offset, 4000);
    expect(notifier().chaptersToStopRemaining, 1);
    player.advance();
    await flush();
    expect(notifier().readAloudPosition.value!.offset, 8000);
    player.advance();
    await flush();
    expect(state().state, PlayerState.idle);
    expect(state().currentIndex, 0);
    expect(player.starts, 1);
  });

  test('改变段间停顿从当前原文位置重建队列，暂停修改仍保持暂停', () async {
    await start();
    player.report(500);
    final anchor = notifier().readAloudPosition.value!.offset;
    await notifier().setReadAloudParagraphInterval(500);
    await flush();
    expect(player.items, hasLength(1));
    expect(notifier().readAloudPosition.value!.offset, anchor);
    notifier().pause();
    await flush();
    await notifier().setReadAloudParagraphInterval(0);
    await flush();
    expect(state().state, PlayerState.paused);
    expect(notifier().readAloudPosition.value!.offset, anchor);
    await notifier().resumeOrPlay();
    await flush();
    expect(state().state, PlayerState.playing);
    expect(player.items, hasLength(3));
  });

  testWidgets('有段间停顿时下一段不提前入播放队列，到时间才起播', (tester) async {
    await tester.runAsync(() async {
      config['ttsParagraphInterval'] = '500';
      await start();
    });
    expect(player.items, hasLength(1));
    player.advance();
    await tester.pump();
    expect(notifier().currentParagraphIndex, 1);
    expect(player.starts, 1);
    await tester.pump(const Duration(milliseconds: 499));
    expect(player.starts, 1);
    await tester.pump(const Duration(milliseconds: 1));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(flush);
    }
    expect(player.starts, 2);
    notifier().stop();
    await tester.runAsync(flush);
  });
}
