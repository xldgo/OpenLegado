import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/domain/models/read_aloud_content.dart';
import 'package:flutter_legado/src/features/read_aloud/cloud_tts_providers.dart';
import 'package:flutter_legado/src/providers/audio/audio_notifier.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../mocks/mocks.dart';

class _Cache extends Fake implements TtsCacheRepository {
  final records = <TtsCacheContext>[];
  @override
  bool get supportsAudioFiles => true;
  @override
  Future<void> record(String path, TtsCacheContext c) async {
    records.add(c);
  }

  @override
  Future<TtsCacheClearResult> clear({
    String? name,
    int? beforeTimestampMs,
    String? keepBookUrl,
    int? keepChapterIndex,
  }) async => const TtsCacheClearResult();
}

class _Api extends MockRustApi {
  final cache = _Cache();
  @override
  TtsCacheRepository get ttsCacheRepository => cache;
}

class _Synth implements CloudTtsSynthesizer {
  final inputs = <String>[];
  final remote = <String>[];
  final cached = <String>{};
  final cancellations = <HttpTtsCancellation>[];
  final pending = <String, Completer<HttpTtsSynthesisResult>>{};
  bool block = false;
  String? failText;
  int active = 0, peak = 0;
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required String engineId,
    required String text,
    String? voiceId,
    Map<String, dynamic>? voiceOptions,
    HttpTtsCancellation? cancellation,
  }) async {
    inputs.add(text);
    cancellations.add(cancellation!);
    if (cached.contains(text)) {
      return HttpTtsAudio(
        audioPath: '/cache/${text.hashCode}.wav',
        fromCache: true,
      );
    }
    remote.add(text);
    active++;
    if (active > peak) peak = active;
    try {
      if (text == failText) throw StateError('本片失败');
      if (block && remote.length > 1) {
        final c = Completer<HttpTtsSynthesisResult>();
        pending[text] = c;
        void cancel() {
          if (!c.isCompleted) c.complete(const HttpTtsCancelled());
        }

        cancellation.addListener(cancel);
        try {
          return await c.future;
        } finally {
          cancellation.removeListener(cancel);
        }
      }
      await Future<void>.delayed(Duration.zero);
      if (cancellation.isCancelled) return const HttpTtsCancelled();
      cached.add(text);
      return HttpTtsAudio(audioPath: '/cache/${text.hashCode}.wav');
    } finally {
      active--;
    }
  }
}

Future<void> flush() async {
  for (var i = 0; i < 35; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerFallbacks);
  late _Api api;
  late _Synth synth;
  late FakeStreamAudioPlayer player;
  late ProviderContainer container;
  late Map<String, String> config;
  AudioNotifier notifier() => container.read(audioNotifierProvider.notifier);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _Api();
    synth = _Synth();
    player = FakeStreamAudioPlayer();
    config = {'audioPreDownloadNum': '1', 'ttsPreSynthesisConcurrency': '2'};
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
        BookChapter(title: '第一章', index: 0),
        BookChapter(title: '第二章', index: 1),
        BookChapter(title: '第三章', index: 2),
      ],
    );
    when(
      () => api.readingRepository.getChapterContentFull(any(), any()),
    ).thenAnswer(
      (c) async =>
          ['${'甲' * 601}\n后续。', '预读。', '窗口外。'][c.positionalArguments[1] as int],
    );
    await api.cloudTtsRepository.save(
      const CloudTtsEngine(
        id: 'ali',
        name: '百炼',
        provider: 'alibaba_cloud',
        model: 'qwen3-tts-flash',
        credentialKey: 'cloud-tts:ali:fixture',
      ),
    );
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        cloudTtsSynthesizerProvider.overrideWithValue(synth),
        streamAudioPlayerProvider.overrideWithValue(player),
      ]),
    );
    await notifier().loadChapters('book');
    await notifier().setGlobalTtsEngine('cloud://ali');
  });
  tearDown(() async {
    notifier().stop();
    await flush();
    container.dispose();
  });
  test('提前合成剩余分片/段落/后续章，缓存文本为实际分片且不提前播放', () async {
    await notifier().play();
    await flush();
    expect(synth.remote.map((t) => t.length), [600, 1, 3, 3]);
    expect(synth.remote, isNot(contains('窗口外。')));
    expect(synth.peak, lessThanOrEqualTo(2));
    expect(player.playedLocalFiles, hasLength(1));
    expect(api.cache.records.first.text.length, 600);
    player.completePlayback();
    await flush();
    expect(player.playedLocalFiles, hasLength(2));
    expect(synth.remote, hasLength(4));
    expect(notifier().currentParagraphIndex, 0);
    player.completePlayback();
    await flush();
    expect(notifier().currentParagraphIndex, 1);
    expect(synth.remote, hasLength(4));
  });
  test('正在预合成的下一片提升为前台不重复请求，停止取消并保持位置', () async {
    synth.block = true;
    await notifier().play();
    await flush();
    expect(synth.peak, 2);
    player.completePlayback();
    await flush();
    expect(synth.remote.where((t) => t == '甲'), hasLength(1));
    expect(player.playedLocalFiles, hasLength(1));
    notifier().stop();
    await flush();
    expect(synth.active, 0);
    expect(player.playedLocalFiles, hasLength(1));
    expect(notifier().prefetchDiagnostics, isEmpty);
  });
  test('片间失败暂停在下一片原文起点，重试不重播已完成片', () async {
    config['audioPreDownloadNum'] = '0';
    synth.failText = '甲';
    await notifier().play();
    await flush();
    player.completePlayback();
    await flush();
    await Future<void>.delayed(const Duration(milliseconds: 550));
    await flush();
    expect(container.read(audioNotifierProvider).state, PlayerState.paused);
    expect(notifier().readAloudPosition.value?.offset, 600);
    expect(notifier().currentParagraphIndex, 0);
    synth.failText = null;
    await notifier().resumeOrPlay();
    await flush();
    expect(synth.remote.where((t) => t.length == 600), hasLength(1));
    expect(player.playedLocalFiles, hasLength(2));
  });
  test('关闭预下载不继续发送背景请求，语速改变不使合成缓存失效', () async {
    config['audioPreDownloadNum'] = '0';
    await notifier().play();
    await flush();
    expect(synth.remote, hasLength(1));
    await notifier().setReadAloudSpeed(1.5);
    await flush();
    expect(synth.remote, hasLength(1));
  });
  test('符号设置立即按原文重建，页面缺失明确报错，有范围后能按页朗读', () async {
    when(() => api.readingRepository.getChapterContentFull(any(), 0))
        .thenAnswer((_) async => '甲。乙！丙');
    await notifier().setContentSplit(ReadAloudSplitMode.symbols, '。！');
    await notifier().play();
    await flush();
    expect(notifier().paragraphCount, 3);
    expect(player.playedLocalFiles, hasLength(1));
    notifier().pause();
    await flush();
    await notifier().setContentSplit(ReadAloudSplitMode.page, '。！');
    expect(container.read(audioNotifierProvider).errorMessage, contains('分页'));
    notifier().registerReadAloudPages('book', 0, '甲。乙！丙', [
      (start: 0, end: 2),
      (start: 2, end: 5),
    ]);
    await notifier().play();
    await flush();
    expect(notifier().paragraphCount, 2);
    expect(notifier().readAloudPosition.value?.paragraphEnd, 2);
  });
}
