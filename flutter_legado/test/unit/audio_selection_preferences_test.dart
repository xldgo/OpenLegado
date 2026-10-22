import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/http_tts_seed.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/audio/application/audio_state.dart';

import '../fixtures/audio_preferences_fixture.dart';

void main() {
  late AudioPreferencesFixture fixture;
  void testServices(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      SharedPreferences.setMockInitialValues({
        kHttpTtsSeedVersionKey: kHttpTtsSeedVersion,
      });
      fixture = AudioPreferencesFixture();
      try {
        await body(tester);
      } finally {
        fixture.close();
      }
    });
  }

  const url = 'https://tts.example/{{text}}';
  const voice = ReadAloudVoice(
    id: 'voice',
    engineType: 'http',
    engineId: '-10',
    speakerId: 'speaker',
    displayName: '音色',
    emotionCatalogJson: '[{"emotionTag":"happy"}]',
  );

  testServices('服务独立装配不读写，书级优先于全局，清书级保留其他配置', (tester) async {
    expect(fixture.bookshelf.reads, isEmpty);
    expect(fixture.bookshelf.writes, isEmpty);
    fixture.bind(
      const Book(
        bookUrl: 'book',
        readConfig: ReadConfig(ttsEngine: 'system://default', openCredits: 20),
      ),
    );
    fixture.state = fixture.state.copyWith(
      config: TtsConfig(engineUrl: url, engineId: 1),
    );
    expect(fixture.selection.resolveTtsEngineUrl(), 'system://default');
    expect(await fixture.selection.resolveTtsEngineId(), isNull);
    await fixture.selection.clearBookTtsEngine();
    expect(fixture.selection.resolveTtsEngineUrl(), url);
    expect(fixture.book?.readConfig?.openCredits, 20);
    expect(fixture.bookshelf.writes, hasLength(1));
    expect(fixture.restarts, 0);
  });

  testServices('跳过设置保存明确作用域，零值可为本书配置且立即更新绑定', (tester) async {
    fixture.bind(
      const Book(
        bookUrl: 'book',
        readConfig: ReadConfig(
          ttsEngine: 'system://default',
          playSpeed: 1.5,
          openCredits: 20,
          closeCredits: 30,
        ),
      ),
    );
    await fixture.preferences.persistSkipCredits(
      'book',
      useGlobal: true,
      openCredits: 10,
      closeCredits: 15,
    );
    expect(fixture.book!.readConfig!.useGlobalAudioSkip, isTrue);
    expect(fixture.book!.readConfig!.openCredits, 20);
    await fixture.preferences.persistSkipCredits(
      'book',
      useGlobal: false,
      openCredits: 0,
      closeCredits: 0,
    );
    final stored = fixture.bookshelf.books['book']!.readConfig!;
    expect(stored.useGlobalAudioSkip, isFalse);
    expect((stored.openCredits, stored.closeCredits), (0, 0));
    expect((stored.ttsEngine, stored.playSpeed), ('system://default', 1.5));
    expect(fixture.book!.readConfig, stored);
    fixture.bind(const Book(bookUrl: 'new-audio-book'));
    await fixture.preferences.persistMode(AudioPlayMode.singleLoop);
    expect(fixture.book!.readConfig!.useGlobalAudioSkip, isTrue);
  });

  testServices('书级HTTP选择保存稳定负数ID，同URL引擎不互换', (tester) async {
    fixture.bind(const Book(bookUrl: 'book'));
    fixture.http.engines = const [
      HttpTts(id: 1, name: '甲', url: url),
      HttpTts(id: -10, name: '乙', url: url),
    ];
    fixture.state = fixture.state.copyWith(
      config: TtsConfig(engineUrl: url, engineId: 1),
    );
    expect(
      await fixture.selection.setBookTtsEngine(url, engineId: -10),
      isTrue,
    );
    expect(fixture.book?.readConfig?.ttsEngine, '-10');
    expect(await fixture.selection.resolveTtsEngineId(), -10);
    expect(fixture.state.config.engineId, 1);
    expect(fixture.selections.engineWrites, isEmpty);
    expect(fixture.restarts, 1);
  });

  testServices('全局选择先清书级并保存新选择，原模式倍速保持', (tester) async {
    fixture.bind(
      const Book(
        bookUrl: 'book',
        readConfig: ReadConfig(
          ttsEngine: 'system://default',
          playMode: 1,
          playSpeed: 1.5,
        ),
      ),
    );
    await fixture.selection.setGlobalTtsEngine('cloud://engine');
    expect(fixture.book?.readConfig?.ttsEngine, isNull);
    expect(fixture.book?.readConfig?.playMode, 1);
    expect(fixture.book?.readConfig?.playSpeed, 1.5);
    expect(fixture.state.config.engineUrl, 'cloud://engine');
    expect(fixture.selections.engineWrites.single.url, 'cloud://engine');
    expect(fixture.restarts, 1);
    expect(await fixture.selection.resolveTtsEngineId(), isNull);
  });

  testServices('读回失效HTTP ID保留其身份，不按相同URL改选其他引擎', (tester) async {
    fixture.selections.engineId = 2;
    fixture.selections.engineUrl = url;
    fixture.http.engines = const [HttpTts(id: 1, name: '其他', url: url)];
    expect(await fixture.selection.loadEffectiveTtsEngineUrl(), '2');
    expect(fixture.state.config.engineId, 2);
    expect(await fixture.selection.resolveTtsEngineId(), isNull);
    expect(fixture.selections.engineWrites, isEmpty);
  });

  testServices('默认选择复用种子门控与规则入口，不选择无效地址', (tester) async {
    fixture.http.engines = const [
      HttpTts(id: 1, name: '无效', url: ''),
      HttpTts(id: 2, name: '有效', url: url),
    ];
    await fixture.selection.ensureDefaultEngine();
    expect(fixture.state.config.engineUrl, url);
    expect(fixture.state.config.engineId, 2);
    expect(fixture.selections.engineWrites, isEmpty);
  });

  testServices('没有当前书不保存书级配置，保存失败不污染已绑定书', (tester) async {
    expect(await fixture.selection.setBookTtsEngine(url), isFalse);
    fixture.bind(
      const Book(
        bookUrl: 'book',
        readConfig: ReadConfig(ttsEngine: 'system://default'),
      ),
    );
    fixture.bookshelf.saveError = StateError('写库失败');
    expect(await fixture.selection.setBookTtsEngine(url), isFalse);
    expect(fixture.book?.readConfig?.ttsEngine, 'system://default');
    expect(fixture.restarts, 0);
    fixture.bookshelf.saveError = null;
    expect(await fixture.selection.setBookTtsEngine(url), isTrue);
    expect(fixture.book?.readConfig?.ttsEngine, url);
  });

  testServices('HTTP音色验证所属引擎与情感，只重启当前引擎', (tester) async {
    fixture.http.engines = const [HttpTts(id: -10, name: '引擎', url: url)];
    fixture.state = fixture.state.copyWith(
      config: TtsConfig(engineUrl: url, engineId: -10),
    );
    await fixture.selection.setHttpTtsVoice(-10, voice, emotionTag: 'happy');
    expect(fixture.selections.httpVoices[-10]?.voiceId, 'voice');
    expect(fixture.selections.httpVoices[-10]?.emotionTag, 'happy');
    expect(fixture.restarts, 1);
    await expectLater(
      fixture.selection.setHttpTtsVoice(-11, voice),
      throwsStateError,
    );
    await expectLater(
      fixture.selection.setHttpTtsVoice(-10, voice, emotionTag: 'missing'),
      throwsStateError,
    );
    expect(fixture.restarts, 1);
    await fixture.selection.setHttpTtsVoice(-10, null);
    expect(fixture.selections.httpVoices[-10], isNull);
    expect(fixture.restarts, 2);
  });

  testServices('云端音色保存不影响其他引擎，当前引擎选择或清除才重启', (tester) async {
    const cloud = ReadAloudVoice(
      id: 'cloud-voice',
      engineType: 'cloud_tts',
      engineId: 'engine',
      speakerId: 'speaker',
      displayName: '云端',
    );
    await fixture.selection.setCloudTtsVoice('engine', cloud);
    expect(fixture.selections.cloudVoices['engine'], 'cloud-voice');
    expect(fixture.restarts, 0);
    fixture.state = fixture.state.copyWith(
      config: TtsConfig(engineUrl: 'cloud://engine'),
    );
    await fixture.selection.setCloudTtsVoice('engine', null);
    expect(fixture.restarts, 1);
    await expectLater(
      fixture.selection.setCloudTtsVoice('other', cloud),
      throwsStateError,
    );
  });

  testServices('读取书级模式倍速只应用，不因打开页面回写', (tester) async {
    const book = Book(
      bookUrl: 'book',
      readConfig: ReadConfig(
        playMode: 2,
        playSpeed: 1.5,
        ttsEngine: 'system://default',
      ),
    );
    fixture.bookshelf.books['book'] = book;
    await fixture.preferences.apply(null, fallbackBookUrl: 'book');
    expect(fixture.book, same(book));
    expect(fixture.state.mode, AudioPlayMode.shuffle);
    expect(fixture.state.config.speed, 1.5);
    await tester.pump(const Duration(seconds: 1));
    expect(fixture.bookshelf.writes, isEmpty);
    expect(fixture.configApplications, 1);
  });

  testServices('越界模式和倍速按原规则处理，读库失败沿用传入书', (tester) async {
    await fixture.preferences.apply(
      const Book(
        bookUrl: 'book',
        readConfig: ReadConfig(playMode: 99, playSpeed: 9),
      ),
    );
    expect(fixture.state.mode, AudioPlayMode.sequential);
    expect(fixture.state.config.speed, 1);
    fixture.bookshelf.readError = StateError('读库失败');
    const incomplete = Book(bookUrl: 'other');
    await fixture.preferences.apply(incomplete);
    expect(fixture.book, same(incomplete));
    expect(fixture.bookshelf.writes, isEmpty);
  });

  testServices('倍速拖动按600ms合并，保留引擎与跳过配置', (tester) async {
    fixture.bind(
      const Book(
        bookUrl: 'book',
        readConfig: ReadConfig(ttsEngine: 'system://default', openCredits: 10),
      ),
    );
    fixture.preferences.scheduleSpeed(1.5);
    fixture.preferences.scheduleSpeed(2);
    await tester.pump(const Duration(milliseconds: 599));
    expect(fixture.bookshelf.writes, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(fixture.bookshelf.writes.single.readConfig?.playSpeed, 2);
    expect(fixture.book?.readConfig?.ttsEngine, 'system://default');
    expect(fixture.book?.readConfig?.openCredits, 10);
  });

  testServices('拖动回原倍速取消待写值，不在稍后写入旧位置', (tester) async {
    fixture.bind(
      const Book(bookUrl: 'book', readConfig: ReadConfig(playSpeed: 1)),
    );
    fixture.preferences.scheduleSpeed(2);
    fixture.preferences.scheduleSpeed(1);
    await tester.pump(const Duration(seconds: 1));
    expect(fixture.bookshelf.writes, isEmpty);
  });

  testServices('模式、引擎与倍速串行合并，互不覆盖其他字段', (tester) async {
    fixture.bind(
      const Book(bookUrl: 'book', readConfig: ReadConfig(openCredits: 7)),
    );
    final gate = Completer<void>();
    fixture.bookshelf.saveBarrier = gate.future;
    final mode = fixture.preferences.persistMode(AudioPlayMode.singleLoop);
    final engine = fixture.selection.setBookTtsEngine(url);
    fixture.preferences.scheduleSpeed(1.8);
    await tester.pump(const Duration(milliseconds: 600));
    expect(fixture.bookshelf.writes, isEmpty);
    gate.complete();
    fixture.bookshelf.saveBarrier = null;
    await Future.wait([mode, engine]);
    await tester.pump();
    expect(fixture.book?.readConfig?.playMode, 1);
    expect(fixture.book?.readConfig?.ttsEngine, url);
    expect(fixture.book?.readConfig?.playSpeed, 1.8);
    expect(fixture.book?.readConfig?.openCredits, 7);
    expect(fixture.audioBook.modes, [1]);
    expect(fixture.bookshelf.writes, hasLength(3));
  });

  testServices('切书后延迟倍速保存原书，不替换当前书籍', (tester) async {
    fixture.bind(
      const Book(bookUrl: 'old', readConfig: ReadConfig(openCredits: 7)),
    );
    fixture.preferences.scheduleSpeed(1.7);
    fixture.bind(
      const Book(bookUrl: 'current', readConfig: ReadConfig(playSpeed: 2)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(fixture.bookshelf.writes.single.bookUrl, 'old');
    expect(fixture.bookshelf.books['old']?.readConfig?.playSpeed, 1.7);
    expect(fixture.book?.bookUrl, 'current');
    expect(fixture.book?.readConfig?.playSpeed, 2);
  });

  testServices('销毁取消尚未执行的倍速写入，读取选择迟到后不访问宿主', (tester) async {
    fixture.bind(const Book(bookUrl: 'book'));
    fixture.preferences.scheduleSpeed(2);
    final gate = Completer<void>();
    fixture.selections.readBarrier = gate.future;
    fixture.selections.engineId = 2;
    final restoring = fixture.selection.restoreGlobalEngine();
    fixture.close();
    gate.complete();
    expect(await restoring, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(fixture.bookshelf.writes, isEmpty);
    expect(fixture.configApplications, 0);
  });

  testServices('全局保存失败沿用原内存选择与错误处理，不回写其他书级字段', (tester) async {
    fixture.bind(
      const Book(
        bookUrl: 'book',
        readConfig: ReadConfig(ttsEngine: 'system://default', openCredits: 8),
      ),
    );
    fixture.selections.saveError = StateError('全局存储失败');
    await fixture.selection.setGlobalTtsEngine(url, engineId: -10);
    expect(fixture.book?.readConfig?.ttsEngine, isNull);
    expect(fixture.book?.readConfig?.openCredits, 8);
    expect(fixture.state.config.engineUrl, url);
    expect(fixture.state.config.engineId, -10);
    expect(fixture.selections.engineWrites, isEmpty);
    expect(fixture.restarts, 1);
  });

  testServices('保存原书引擎期间切书，原书落库后不重启或替换新书', (tester) async {
    fixture.bind(const Book(bookUrl: 'old'));
    final gate = Completer<void>();
    fixture.bookshelf.saveBarrier = gate.future;
    final saving = fixture.selection.setBookTtsEngine(url);
    await tester.pump();
    fixture.bind(
      const Book(
        bookUrl: 'new',
        readConfig: ReadConfig(ttsEngine: 'system://default'),
      ),
    );
    gate.complete();
    expect(await saving, isTrue);
    expect(fixture.bookshelf.books['old']?.readConfig?.ttsEngine, url);
    expect(fixture.book?.bookUrl, 'new');
    expect(fixture.book?.readConfig?.ttsEngine, 'system://default');
    expect(fixture.restarts, 0);
  });

  testServices('倍速保存失败后可以再次保存，未发布失败的书级快照', (tester) async {
    fixture.bind(
      const Book(bookUrl: 'book', readConfig: ReadConfig(playSpeed: 1)),
    );
    fixture.bookshelf.saveError = StateError('写入失败');
    fixture.preferences.scheduleSpeed(2);
    await tester.pump(const Duration(milliseconds: 600));
    expect(fixture.book?.readConfig?.playSpeed, 1);
    fixture.bookshelf.saveError = null;
    fixture.preferences.scheduleSpeed(2);
    await tester.pump(const Duration(milliseconds: 600));
    expect(fixture.book?.readConfig?.playSpeed, 2);
    expect(fixture.bookshelf.writes, hasLength(1));
  });

  testServices('独立服务实例的书籍配置和选择互不影响', (tester) async {
    final other = AudioPreferencesFixture();
    try {
      fixture.bind(const Book(bookUrl: 'book'));
      other.bind(const Book(bookUrl: 'book'));
      await fixture.selection.setBookTtsEngine(url);
      await other.selection.setBookTtsEngine('system://default');
      expect(fixture.selection.resolveTtsEngineUrl(), url);
      expect(other.selection.resolveTtsEngineUrl(), 'system://default');
      fixture.close();
      await other.preferences.persistMode(AudioPlayMode.shuffle);
      expect(other.book?.readConfig?.playMode, 2);
    } finally {
      other.close();
    }
  });
}
