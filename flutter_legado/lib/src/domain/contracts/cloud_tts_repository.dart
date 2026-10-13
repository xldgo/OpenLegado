import 'dart:convert';

/// 云端元数据不包含明文凭据，播放参数源于 optionsJson。— Codex + Bridge
final class CloudTtsEngine {
  const CloudTtsEngine({
    required this.id,
    required this.name,
    this.provider = 'openai_speech',
    this.baseUrl = '',
    this.model = 'gpt-4o-mini-tts',
    this.optionsJson = '{}',
    this.region = '',
    this.appId = '',
    this.enabled = true,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.credentialKey = '',
  });
  final String id,
      name,
      provider,
      baseUrl,
      model,
      optionsJson,
      region,
      appId,
      credentialKey;
  final bool enabled;
  final int createdAt, updatedAt;
  String get selection => 'cloud://$id';
  Map<String, dynamic> get options =>
      jsonDecode(optionsJson) as Map<String, dynamic>;
  factory CloudTtsEngine.fromJson(Map<String, dynamic> j) => CloudTtsEngine(
    id: j['id'] as String,
    name: j['name'] as String,
    provider: j['provider'] as String,
    baseUrl: j['baseUrl'] as String,
    model: j['model'] as String,
    optionsJson: j['optionsJson'] as String,
    region: j['region'] as String,
    appId: j['appId'] as String,
    enabled: j['enabled'] as bool,
    createdAt: j['createdAt'] as int,
    updatedAt: j['updatedAt'] as int,
    credentialKey: j['credentialKey'] as String,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider,
    'baseUrl': baseUrl,
    'model': model,
    'optionsJson': optionsJson,
    'region': region,
    'appId': appId,
    'enabled': enabled,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'credentialKey': credentialKey,
  };
  CloudTtsEngine withCredential(String key) => CloudTtsEngine(
    id: id,
    name: name,
    provider: provider,
    baseUrl: baseUrl,
    model: model,
    optionsJson: optionsJson,
    region: region,
    appId: appId,
    enabled: enabled,
    createdAt: createdAt,
    updatedAt: updatedAt,
    credentialKey: key,
  );
}

bool isCloudTts(String selection) => selection.startsWith('cloud://');
String cloudTtsId(String selection) {
  final id = selection.substring('cloud://'.length);
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
    throw const FormatException('云端引擎标识无效');
  }
  return id;
}

abstract interface class CloudTtsRepository {
  Future<List<CloudTtsEngine>> list();
  Future<void> save(CloudTtsEngine engine);
  Future<void> delete(String id);
  Future<List<String>> voices(String provider);
}
