import 'package:flutter_legado/src/features/read_aloud/http_tts_seed.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/repositories/mock_http_tts_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/features/read_aloud/http_tts_voice_selection.dart';
import 'package:flutter_legado/src/features/read_aloud/read_aloud_voice_provider.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';

void main() {
  test('HTTP 预设默认情感、显式默认覆盖与无目录标签保持不同语义', () {
    const voice = ReadAloudVoice(
      id: 'preset',
      engineType: 'http',
      engineId: '1',
      speakerId: 'a',
      displayName: '预设',
      traitsJson: '{"tags":["女"],"emotionTag":"happy"}',
      emotionCatalogJson: '[{"emotionName":"高兴","emotionTag":"happy"},{"emotionName":"平静","emotionTag":"calm"}]',
    );
    expect(
      resolveHttpTtsVoice(1, [
        voice,
      ], const HttpTtsVoiceSelection('preset')).emotionTag,
      'happy',
    );
    expect(
      resolveHttpTtsVoice(1, [
        voice,
      ], const HttpTtsVoiceSelection('preset', emotionTag: '')).emotionTag,
      isNull,
    );
    expect(
      resolveHttpTtsVoice(1, [
        voice,
      ], const HttpTtsVoiceSelection('preset', emotionTag: 'calm')).emotionTag,
      'calm',
    );
    final stale = resolveHttpTtsVoice(1, [
      voice,
    ], const HttpTtsVoiceSelection('preset', emotionTag: 'removed'));
    expect(stale.emotionTag, isNull);
    expect(stale.warning, isNotNull);
    final custom = voice.copyWith(
      emotionCatalogJson: '[]',
      traitsJson: '{"emotionTag":"custom"}',
    );
    expect(
      resolveHttpTtsVoice(1, [
        custom,
      ], const HttpTtsVoiceSelection('preset')).emotionTag,
      'custom',
    );
  });
  test('平铺优先分组，同音色首项保留，别名、标签与情感贯通', () async {
    final voices = MockReadAloudVoiceRepository();
    var id = 1;
    final repo = MockHttpTtsRepository(
      nextId: () => id++,
      voiceCatalog: voices,
    );
    await repo.importHttpTts(
      jsonEncode([
        {
          'id': 1,
          'name': '源',
          'url': 'https://tts',
          'speakersJson': jsonEncode([
            {
              'items': [
                {'name': '分组', 'tone_id': 'a'},
                {'name': '乙', 'toneId': 'b'},
              ],
            },
            {
              'speakerName': '平铺',
              'toneID': 'a',
              'tags': ['女', 1, false],
            },
          ]),
          'emotionsJson': jsonEncode([
            {'emotionName': '高兴', 'value': 'happy'},
          ]),
        },
      ]),
    );
    final catalog = await voices.list();
    expect(catalog.map((v) => v.displayName), ['平铺', '乙']);
    expect(jsonDecode(catalog[0].traitsJson), ['女', '1', 'false']);
    expect(jsonDecode(catalog[0].emotionCatalogJson), [
      {'emotionName': '高兴', 'emotionTag': 'happy'},
    ]);
  });
  test('重复导入保留排除/禁用，缺目录不清空；引擎删除只影响对应目录', () async {
    final voices = MockReadAloudVoiceRepository();
    var id = 1;
    final repo = MockHttpTtsRepository(
      nextId: () => id++,
      voiceCatalog: voices,
    );
    String source(int id, String tone) => jsonEncode([
      {
        'id': id,
        'name': '源$id',
        'url': 'https://tts',
        'speakersJson': jsonEncode([
          {'speakerName': '中文', 'toneID': tone},
        ]),
      },
    ]);
    await repo.importHttpTts(source(1, 'a'));
    await repo.importHttpTts(source(2, 'b'));
    final first = (await voices.list()).first;
    await voices.setFlags(first.id, enabled: false, excluded: true);
    await repo.importHttpTts(source(1, 'a'));
    await repo.importHttpTts('[{"id":1,"name":"改名","url":"https://new"}]');
    final catalog = await voices.list();
    expect(catalog, hasLength(2));
    expect(catalog.first.enabled, false);
    expect(catalog.first.excluded, true);
    await repo.deleteHttpTts(1);
    expect((await voices.list()).single.engineId, '2');
  });
  test('系统目录稳定 ID、去重和不可用重现仍保留用户标记', () async {
    final repo = MockReadAloudVoiceRepository();
    final entries = systemVoiceEntries(const [
      SystemTtsVoice(name: '同名', locale: 'zh-TW'),
      SystemTtsVoice(name: '同名', locale: 'zh-CN'),
      SystemTtsVoice(name: '中文', locale: 'zh-CN', identifier: 'ios.id'),
    ]);
    expect(entries, hasLength(2));
    await repo.syncSystem('system:device', entries);
    final voice = (await repo.list()).first;
    expect(voice.id, startsWith('voice:'));
    expect(voice.id.length, 38);
    await repo.setFlags(voice.id, enabled: true, excluded: true);
    await repo.syncSystem('system:device', []);
    expect((await repo.list()).first.available, false);
    await repo.syncSystem('system:device', entries);
    expect((await repo.list()).first.excluded, true);
    expect((await repo.list()).first.available, true);
  });
  test('HTTP 选择按引擎隔离，排除或缺失不选其他音色，情感不存在时提示', () {
    const voice = ReadAloudVoice(
      id: 'v',
      engineType: 'http',
      engineId: '1',
      speakerId: 'tone',
      displayName: '中文',
      emotionCatalogJson: '[{"emotionName":"高兴","emotionTag":"happy"}]',
    );
    expect(
      resolveHttpTtsVoice(1, [
        voice,
      ], const HttpTtsVoiceSelection('v', emotionTag: 'happy')).emotionTag,
      'happy',
    );
    expect(
      resolveHttpTtsVoice(2, [voice], const HttpTtsVoiceSelection('v')).voice,
      isNull,
    );
    expect(
      resolveHttpTtsVoice(1, [
        voice.copyWith(excluded: true),
      ], const HttpTtsVoiceSelection('v')).warning,
      isNotNull,
    );
    final missing = resolveHttpTtsVoice(1, [
      voice,
    ], const HttpTtsVoiceSelection('v', emotionTag: 'sad'));
    expect(missing.voice, voice);
    expect(missing.emotionTag, isNull);
    expect(missing.warning, isNotNull);
  });
  test('目录对象/数组字段和缺发音人ID按上游丢弃，不凭名称造音色', () async {
    final repo = MockReadAloudVoiceRepository();
    repo.importHttp(1, {
      'speakersJson': [
        {'speakerName': '中文', 'toneID': 'a'},
      ],
    });
    repo.importHttp(1, {'speakersJson': '[{"speakerName":"没有ID"}]'});
    expect(await repo.list(), isEmpty);
  });
  test('默认 Flutter 种子导入保留原始音色/情感目录，重复同步不改用户标记', () async {
    final voices = MockReadAloudVoiceRepository();
    var next = 1;
    final repo = MockHttpTtsRepository(
      nextId: () => next++,
      voiceCatalog: voices,
    );
    final raw = jsonEncode([
      {
        'id': -1,
        'name': '预设',
        'url': 'https://tts',
        'speakersJson': '[{"name":"中文","toneID":"a"}]',
        'emotionsJson': '[{"name":"高兴","tag":"happy"}]',
      },
    ]);
    expect(await syncDefaultHttpTts(repo, jsonOverride: raw), 1);
    final voice = (await voices.list()).single;
    await voices.setFlags(voice.id, enabled: false, excluded: true);
    expect(await syncDefaultHttpTts(repo, jsonOverride: raw), 0);
    expect((await voices.list()).single.excluded, true);
    expect(
      jsonDecode((await voices.list()).single.emotionCatalogJson)
          .single['emotionTag'],
      'happy',
    );
  });
}
