import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/repositories/mock_config_repository.dart';
import 'package:flutter_legado/src/data/repositories/config_read_aloud_selection_repository.dart';
import 'package:flutter_legado/src/data/repositories/config_txt_toc_rule_repository.dart';
import 'package:flutter_legado/src/data/repositories/config_source_variable_repository.dart';
import 'package:flutter_legado/src/data/repositories/config_server_access_repository.dart';
import 'package:flutter_legado/src/domain/models/http_tts_voice_selection.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/config_provider.dart';
import 'package:flutter_legado/src/providers/config_settings_provider.dart';
import 'package:flutter_legado/src/providers/media_provider.dart';
import 'package:flutter_legado/src/providers/domain_config_provider.dart';

import '../fixtures/mock_book_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Mock配置与已拆分服务共享，枚举返回副本，删除不影响其他键', () async {
    final api = MockBookApi();
    await api.readingContentService.setChineseConvertType(2);
    expect(await api.configRepository.getConfig('chineseConverterType'), '2');
    await api.configRepository.setConfig('ttsVoice:1', '音色');
    final all = await api.configRepository.getAllConfigs();
    all.clear();
    expect(await api.configRepository.getConfig('ttsVoice:1'), '音色');
    await api.configRepository.deleteConfig('ttsVoice:1');
    expect(await api.readingContentService.getChineseConvertType(), 2);
    expect(await api.configRepository.getConfig('ttsVoice:1'), isNull);
    await api.networkService.setCustomHosts('{"a":"127.0.0.1"}');
    expect(
      await api.configRepository.getConfig('customHosts'),
      '{"a":"127.0.0.1"}',
    );
  });
  test('朗读引擎身份、云音色和HTTP情感选择分别保存与清除', () async {
    final config = MockConfigRepository();
    final choices = ConfigReadAloudSelectionRepository(config);
    await choices.setEngine('http://tts', httpEngineId: 8);
    expect(await choices.getEngineUrl(), 'http://tts');
    expect(await choices.getHttpEngineId(), 8);
    await choices.setEngine('system://default');
    expect(await choices.getHttpEngineId(), isNull);
    await choices.setCloudVoice('cloud', '声音');
    await choices.setHttpVoice(
      8,
      const HttpTtsVoiceSelection('v', emotionTag: 'happy'),
    );
    final value = await choices.getHttpVoice(8);
    expect(value?.voiceId, 'v');
    expect(value?.emotionTag, 'happy');
    expect(await choices.getCloudVoice('cloud'), '声音');
    expect(await choices.getHttpVoice(9), isNull);
    await choices.setHttpVoice(8, null);
    await choices.setCloudVoice('cloud', null);
    expect(await choices.getHttpVoice(8), isNull);
    expect(await choices.getCloudVoice('cloud'), '');
    await config.setConfig('ttsVoice:8', '[]');
    await expectLater(choices.getHttpVoice(8), throwsA(isA<TypeError>()));
  });
  test('目录规则完整往返，坏响应拒绝，变量和令牌不混入规则', () async {
    final config = MockConfigRepository();
    final rules = ConfigTxtTocRuleRepository(config);
    final rule = TxtTocRule(
      id: 9,
      name: '章节',
      rule: r'^第.*章',
      enable: false,
      serialNumber: 7,
    );
    await rules.saveRules([rule]);
    expect((await rules.getRules()).single, rule);
    final variables = ConfigSourceVariableRepository(config),
        other = ConfigSourceVariableRepository(config);
    await variables.write('source', '变量');
    expect(await other.read('source'), '变量');
    expect(await variables.read('other'), isNull);
    final token = ConfigServerAccessRepository(config);
    await token.setToken('secret');
    await variables.write('source', '');
    expect(await variables.read('source'), isNull);
    expect(await token.getToken(), 'secret');
    await token.setToken('');
    expect(await token.getToken(), isNull);
    expect((await rules.getRules()).single, rule);
    await config.setConfig('txt_toc_rules', '{}');
    await expectLater(rules.getRules(), throwsA(isA<TypeError>()));
  });
  test('只注入配置仓储即可装配领域入口，不访问根API或原生库', () async {
    final config = MockConfigRepository();
    final container = ProviderContainer(
      overrides: [configRepositoryProvider.overrideWithValue(config)],
    );
    addTearDown(container.dispose);
    await container
        .read(readAloudSelectionRepositoryProvider)
        .setCloudVoice('a', '声音');
    expect(await config.getConfig('cloudTtsVoice:a'), '声音');
    await container.read(sourceVariableRepositoryProvider).write('a', '值');
    expect(await config.getConfig('sourceVariable_a'), '值');
    await container.read(serverAccessRepositoryProvider).setToken('token');
    expect(await config.getConfig('jsSourceApiToken'), 'token');
    await container
        .read(audioPlaybackSettingsRepositoryProvider)
        .update((s) => s.copyWith(openCredits: 12));
    expect(await config.getConfig('audioSkipOpenCredits'), '12');
    final progress = container.read(videoProgressRepositoryProvider);
    await progress.write('video', 123);
    expect(await progress.read('video'), 123);
  });
}
