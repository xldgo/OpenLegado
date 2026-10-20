import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/app/bootstrap/application_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_legado/src/data/repositories/mock_config_repository.dart';
import 'package:flutter_legado/src/data/services/rust_reading_content_service.dart';
import 'package:flutter_legado/src/data/repositories/rust_bookshelf_repository.dart';
import 'package:flutter_legado/src/providers/config_settings_provider.dart';
import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/runtime_configuration_sync.dart';
import 'package:flutter_legado/src/features/appearance/appearance_settings_provider.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/domain/models/audio_media.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../mocks/mocks.dart';

class _Bootstrap extends Mock implements RustBootstrap {}

class _Sync extends Mock implements RuntimeConfigurationSync {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('正式启动、主题和阅读配置共用同一Bootstrap，无第二套初始化', () async {
    final bootstrap = _Bootstrap();
    final sync = _Sync();
    when(() => bootstrap.configurationSync).thenReturn(sync);
    when(bootstrap.initialize).thenAnswer((_) async {});
    final container = createApplicationContainer(
      useMock: false,
      bootstrap: bootstrap,
    );
    addTearDown(container.dispose);
    expect(container.read(themeConfigSyncProvider), same(sync));
    expect(container.read(readingConfigSyncProvider), same(sync));
    verifyNever(bootstrap.initialize);
    await initializeApplication(container);
    verify(bootstrap.initialize).called(1);
  });
  test('Mock下载、缓存读取与清理共享数据，不跨容器泄漏', () async {
    final first = createApplicationContainer(useMock: true);
    final second = createApplicationContainer(useMock: true);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final result = await first
        .read(audioCacheDownloadServiceProvider)
        .audioCacheDownload(
          bookUrl: 'fixture://book',
          chapterIndex: 3,
          chapterUrl: 'chapter',
          chapterTitle: '第三章',
          playUrl: 'https://audio.test/3.mp3',
        );
    expect(result.status, AudioCacheDownloadStatus.installed);
    final cache = first.read(audioCacheRepositoryProvider);
    expect(await cache.audioCacheList(bookUrl: 'fixture://book'), [3]);
    expect(
      await second
          .read(audioCacheRepositoryProvider)
          .audioCacheList(bookUrl: 'fixture://book'),
      isEmpty,
    );
    expect(await cache.audioCacheClearBook(bookUrl: 'fixture://book'), 1);
    expect(await cache.audioCacheList(bookUrl: 'fixture://book'), isEmpty);
  });
  test('Mock HTTP引擎与音色目录共用状态，删除引擎清除所属音色', () async {
    final container = createApplicationContainer(useMock: true);
    addTearDown(container.dispose);
    final engines = container.read(httpTtsRepositoryProvider);
    final voices = container.read(readAloudVoiceRepositoryProvider);
    final engine = await engines.addHttpTts(
      const HttpTts(name: '测试引擎', url: 'https://tts.test'),
    );
    final id = readAloudVoiceId('http', '${engine.id}', 'zh');
    await voices.save(
      ReadAloudVoice(
        id: id,
        engineType: 'http',
        engineId: '${engine.id}',
        speakerId: 'zh',
        displayName: '中文',
        traitsJson: '{}',
      ),
    );
    expect((await voices.list()).map((voice) => voice.id), contains(id));
    await engines.deleteHttpTts(engine.id);
    expect((await voices.list()).map((voice) => voice.id), isNot(contains(id)));
  });
  test('正式装配只构造能力，读取仓储不隐式初始化原生库', () {
    final container = createApplicationContainer(useMock: false);
    addTearDown(container.dispose);
    expect(
      container.read(readingContentServiceProvider),
      isA<RustReadingContentService>(),
    );
    expect(
      container.read(bookshelfRepositoryProvider),
      isA<RustBookshelfRepository>(),
    );
    expect(
      container.read(bookshelfRepositoryProvider),
      same(container.read(bookshelfRepositoryProvider)),
    );
  });
  test('Mock同一容器跨领域共享配置、书架和章节；新容器隔离', () async {
    final first = createApplicationContainer(useMock: true),
        second = createApplicationContainer(useMock: true);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await initializeApplication(first);
    final books = await first.read(bookshelfRepositoryProvider).getBooks();
    expect(books, isNotEmpty);
    final book = books.first;
    final chapters = await first
        .read(readingRepositoryProvider)
        .getChapters(book.bookUrl);
    expect(chapters, isNotEmpty);
    await first
        .read(bookshelfRepositoryProvider)
        .updateBook(book.copyWith(name: '同一存储'));
    expect(
      (await first.read(bookshelfRepositoryProvider).getBook(book.bookUrl))
          ?.name,
      '同一存储',
    );
    expect(
      (await second.read(bookshelfRepositoryProvider).getBook(book.bookUrl))
          ?.name,
      isNot('同一存储'),
    );
    await first.read(readingContentServiceProvider).setChineseConvertType(2);
    expect(
      await first
          .read(configRepositoryProvider)
          .getConfig('chineseConverterType'),
      '2',
    );
    expect(
      await second
          .read(configRepositoryProvider)
          .getConfig('chineseConverterType'),
      isNull,
    );
    await first.read(localServerServiceProvider).setMcpPort(1236);
    expect(
      (await first.read(serviceSettingsRepositoryProvider).load()).mcpPort,
      1236,
    );
  });
  test('Mock中仍可单独替换配置仓储和运行时，不冲突或访问原生', () async {
    final runtime = AppRuntimeMock();
    final ready = Completer<void>();
    when(() => runtime.initialize()).thenAnswer((_) => ready.future);
    final config = MockConfigRepository(values: {'audioSkipOpenCredits': '12'});
    final container = createApplicationContainer(
      useMock: true,
      overrides: [
        appRuntimeProvider.overrideWithValue(runtime),
        configRepositoryProvider.overrideWithValue(config),
      ],
    );
    addTearDown(container.dispose);
    var initialized = false;
    final startup = initializeApplication(container)
        .then((_) => initialized = true);
    await Future<void>.delayed(Duration.zero);
    expect(initialized, isFalse);
    ready.complete();
    await startup;
    expect(initialized, isTrue);
    expect(
      (await container.read(audioPlaybackSettingsRepositoryProvider).load())
          .openCredits,
      12,
    );
    verify(() => runtime.initialize()).called(1);
  });
  test('启动失败原样传播，调用方不会把容器当作已就绪', () async {
    final runtime = AppRuntimeMock();
    final error = StateError('数据库打开失败');
    when(() => runtime.initialize()).thenAnswer((_) async => throw error);
    final container = createApplicationContainer(
      useMock: false,
      overrides: [appRuntimeProvider.overrideWithValue(runtime)],
    );
    addTearDown(container.dispose);
    await expectLater(initializeApplication(container), throwsA(same(error)));
    verify(() => runtime.initialize()).called(1);
  });
  test('Mock书源与hosts共享配置，设置同步不访问原生', () async {
    final container = createApplicationContainer(useMock: true);
    addTearDown(container.dispose);
    final reading = container.read(readingConfigSyncProvider);
    await reading.refreshReadBookConfig();
    expect(
      container.read(bookSourceRepositoryProvider),
      same(container.read(bookSourceRepositoryProvider)),
    );
    final sources = await container
        .read(bookSourceRepositoryProvider)
        .getBookSources();
    expect(sources, isNotEmpty);
    await container
        .read(networkServiceProvider)
        .setCustomHosts('{"host":"127.0.0.1"}');
    expect(
      await container.read(configRepositoryProvider).getConfig('customHosts'),
      '{"host":"127.0.0.1"}',
    );
  });
}
