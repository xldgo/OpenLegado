import 'package:flutter_legado/src/bridge/media_dto.dart' as dto;
import 'package:flutter_legado/src/data/bridge/media_dto_mapping.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTTP完整字段、可空标志和64位标识往返不丢失', () {
    const v = HttpTts(
      id: 9007199254740993,
      name: '中文😀',
      url: '@js:result',
      contentType: 'audio/wav',
      pauseDuration: 2147483647,
      concurrentRate: '1000',
      loginUrl: 'login()',
      loginUi: '[]',
      header: '{}',
      jsLib: 'var a=1;',
      enabledCookieJar: null,
      loginCheckJs: 'result',
      speed: -2147483648,
      synthesisThreadCount: 8,
      lastUpdateTime: 9007199254740993,
      isEnabled: false,
    );
    expect(httpTtsFromDto(httpTtsToDto(v)), v);
    expect(
      httpTtsToDto(v.copyWith(synthesisThreadCount: -1)).synthesisThreadCount,
      1,
    );
    expect(() => httpTtsToDto(v.copyWith(speed: 2147483648)), throwsRangeError);
    expect(
      () => httpTtsToDto(v.copyWith(pauseDuration: -2147483649)),
      throwsRangeError,
    );
  });
  test('云供应商穷举往返与完整元数据映射', () {
    for (final provider in ['openai_speech', 'mimo', 'alibaba_cloud']) {
      const v = CloudTtsEngine(
        id: 'id',
        name: '名称',
        baseUrl: 'https://endpoint',
        model: 'model',
        optionsJson: '{"voiceId":"a"}',
        region: 'region',
        appId: 'app',
        enabled: false,
        createdAt: 9007199254740993,
        updatedAt: 3,
        credentialKey: '凭据引用',
      );
      final encoded = cloudEngineToDto(
        CloudTtsEngine.fromJson({...v.toJson(), 'provider': provider}),
      );
      expect(cloudEngineFromDto(encoded).toJson(), {
        ...v.toJson(),
        'provider': provider,
      });
    }
    expect(() => cloudProviderToDto('unknown'), throwsFormatException);
  });
  test('试听参数拒绝未知字段与非有限语速，保留显式零值', () {
    final options = cloudVoiceOptionsToDto({
      'voiceId': '声线',
      'locale': 'English',
      'style': '高兴',
      'role': '旁白',
      'instructions': '中文',
      'speed': 0,
      'pitch': 1.2,
      'volume': 0,
      'format': 'wav',
      'sampleRate': 24000,
    });
    expect(
      options,
      const dto.CloudVoiceOptionsDto(
        voiceId: '声线',
        locale: 'English',
        style: '高兴',
        role: '旁白',
        instructions: '中文',
        speed: 0,
        pitch: 1.2,
        volume: 0,
        format: 'wav',
        sampleRate: 24000,
      ),
    );
    expect(
      () => cloudVoiceOptionsToDto({'apiKey': '不可混入'}),
      throwsFormatException,
    );
    for (final key in ['speed', 'pitch', 'volume']) {
      for (final number in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => cloudVoiceOptionsToDto({key: number}),
          throwsArgumentError,
        );
      }
    }
    for (final sampleRate in [-1, 0x100000000]) {
      expect(
        () => cloudVoiceOptionsToDto({'sampleRate': sampleRate}),
        throwsArgumentError,
      );
    }
    expect(cloudVoiceOptionsToDto({}).pitch, isNull);
    expect(cloudVoiceOptionsToDto({'sampleRate': 0}).sampleRate, 0);
  });
  test('音色十四字段、系统目录协议文档原样往返', () {
    const voice = ReadAloudVoice(
      id: 'id',
      engineType: 'http',
      engineId: '17',
      speakerId: 'speaker',
      displayName: '中文',
      traitsJson: '["a"]',
      emotionCatalogJson: '[{"tag":"happy"}]',
      managedBy: 'http',
      enabled: false,
      available: false,
      excluded: true,
      revision: 9007199254740993,
      createdAt: 1,
      updatedAt: 2,
    );
    expect(
      readAloudVoiceFromDto(readAloudVoiceToDto(voice)).toJson(),
      voice.toJson(),
    );
    const system = SystemVoiceCatalogEntry(
      speakerId: 'id',
      displayName: '中文',
      traitsJson: '["offline"]',
    );
    expect(
      systemVoiceFromDto(systemVoiceToDto(system)).toJson(),
      system.toJson(),
    );
  });
  test('缓存上下文拒绝无符号溢出，摘要大小不截成32位', () {
    const context = TtsCacheContext(
      bookUrl: 'book',
      bookName: '名称',
      chapterIndex: 4294967295,
      chapterTitle: '章',
      paragraphIndex: 0,
      text: '正文😀',
    );
    final encoded = ttsCacheContextToDto(context);
    expect(ttsCacheContextFromDto(encoded).toJson(), context.toJson());
    expect(
      () => ttsCacheContextToDto(
        const TtsCacheContext(
          bookUrl: '',
          bookName: '',
          chapterIndex: -1,
          chapterTitle: '',
          paragraphIndex: 0,
          text: '',
        ),
      ),
      throwsRangeError,
    );
    expect(
      () => ttsCacheContextToDto(
        const TtsCacheContext(
          bookUrl: '',
          bookName: '',
          chapterIndex: 0,
          chapterTitle: '',
          paragraphIndex: 4294967296,
          text: '',
        ),
      ),
      throwsRangeError,
    );
    final entry = ttsCacheEntryFromDto(
      dto.TtsCacheEntryDto(
        name: 'a.wav',
        sizeBytes: BigInt.from(9007199254740993),
        modifiedAtMs: BigInt.from(1700000000000),
        protected: true,
        contexts: [encoded],
      ),
    );
    expect(entry.sizeBytes, 9007199254740993);
    expect(entry.protected, isTrue);
    expect(entry.contexts.single.toJson(), context.toJson());
    expect(() => entry.contexts.clear(), throwsUnsupportedError);
    final clear = ttsCacheClearResultFromDto(
      dto.TtsCacheClearResultDto(
        removedFiles: BigInt.from(2),
        removedBytes: BigInt.from(9007199254740993),
        skippedFiles: BigInt.one,
      ),
    );
    expect(
      [clear.removedFiles, clear.removedBytes, clear.skippedFiles],
      [2, 9007199254740993, 1],
    );
  });
  test('音频章节URL保留领域url字段语义', () {
    final value = audioChapterMediaFromDto(
      const dto.AudioChapterMediaDto(
        chapterIndex: 7,
        title: '章',
        mediaUrl: 'audio',
        chapterUrl: 'chapter',
        resourceUrl: 'resource',
        isVolume: true,
        fromCache: false,
        lyric: '歌词',
        sourceUrl: 'source',
      ),
    );
    expect(
      [
        value.chapterIndex,
        value.title,
        value.mediaUrl,
        value.url,
        value.resourceUrl,
        value.isVolume,
        value.fromCache,
        value.lyric,
        value.sourceUrl,
      ],
      [7, '章', 'audio', 'chapter', 'resource', true, false, '歌词', 'source'],
    );
  });
}
