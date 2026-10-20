import '../../domain/contracts/cloud_tts_provider.dart';
import '../../domain/contracts/cloud_tts_repository.dart';

final class MockCloudTtsRepository implements CloudTtsRepository {
  MockCloudTtsRepository({this.onDelete});
  final void Function(String)? onDelete;
  final _engines = <String, CloudTtsEngine>{};
  @override
  Future<List<CloudTtsEngine>> list() async =>
      List.unmodifiable(_engines.values);
  @override
  Future<void> save(CloudTtsEngine engine) async {
    if (!cloudTtsProviderProfiles.containsKey(engine.provider) ||
        engine.name.trim().isEmpty ||
        engine.credentialKey.isEmpty) {
      throw StateError('云端配置无效');
    }
    if (cloudTtsProfile(engine.provider).requiresAppId &&
        engine.appId.trim().isEmpty) {
      throw StateError('App ID 不能为空');
    }
    final options = engine.options;
    const allowed = {
      'voiceId',
      'locale',
      'role',
      'pitch',
      'volume',
      'sampleRate',
      'speed',
      'style',
      'instructions',
      'format',
    };
    if (options.keys.any((k) => !allowed.contains(k))) {
      throw StateError('云端选项无效');
    }
    final previous = _engines[engine.id];
    if ((engine.provider == 'aws_polly' ||
            engine.provider == 'azure_speech' && engine.baseUrl.isEmpty) &&
        engine.region.trim().isEmpty) {
      throw StateError('Azure 区域不能为空');
    }
    if (previous != null && previous.provider != engine.provider) {
      throw StateError('已保存引擎不能更换 Provider，请新建引擎');
    }
    final format = options['format'];
    if (format != null &&
        !cloudTtsProfile(engine.provider).formats.contains(format)) {
      throw StateError('云端音频格式不支持');
    }
    _engines[engine.id] = engine;
  }

  @override
  Future<void> delete(String id) async {
    if (_engines.remove(id) == null) throw StateError('云端引擎不存在');
    onDelete?.call(id);
  }

  @override
  Future<List<String>> voices(String provider) async {
    if (cloudTtsProfile(provider).remoteCatalog) return const [];
    if (provider == 'gemini_tts') {
      return const [
        'Kore',
        'Puck',
        'Charon',
        'Fenrir',
        'Leda',
        'Orus',
        'Aoede',
        'Callirrhoe',
        'Autonoe',
        'Enceladus',
        'Iapetus',
        'Umbriel',
        'Algieba',
        'Despina',
        'Erinome',
        'Algenib',
        'Rasalgethi',
        'Laomedeia',
        'Achernar',
        'Alnilam',
        'Schedar',
        'Gacrux',
        'Pulcherrima',
        'Achird',
        'Zubenelgenubi',
        'Vindemiatrix',
        'Sadachbia',
        'Sadaltager',
        'Sulafat',
        'Zephyr',
      ];
    }
    if (provider == 'volcengine') {
      return const [
        'BV001_streaming',
        'BV002_streaming',
        'BV700_streaming',
        'BV701_streaming',
      ];
    }
    if (provider == 'alibaba_cloud') {
      return const ['Cherry', 'Serena', 'Ethan', 'Chelsie'];
    }
    if (provider == 'mimo') {
      return const [
        'mimo_default',
        '冰糖',
        '茉莉',
        '苏打',
        '白桦',
        'Mia',
        'Chloe',
        'Milo',
        'Dean',
      ];
    }
    if (provider != 'openai_speech') throw StateError('云端 Provider 未支持');
    return const [
      'alloy',
      'ash',
      'ballad',
      'coral',
      'echo',
      'fable',
      'nova',
      'onyx',
      'sage',
      'shimmer',
      'verse',
      'marin',
      'cedar',
    ];
  }
}
