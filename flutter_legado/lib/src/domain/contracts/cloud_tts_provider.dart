/// 配置表单支持的服务商与默认值；合成规则以 Rust Provider 为准。— Codex + Bridge
final class CloudTtsProviderProfile {
  const CloudTtsProviderProfile({
    required this.name,
    required this.model,
    required this.voice,
    required this.formats,
    this.styles = const [],
    this.supportsSourceSpeed = false,
    this.supportsLocale = false,
    this.supportsProsody = false,
    this.requiresRegion = false,
    this.usesModel = true,
    this.usesSecretKey = false,
    this.remoteCatalog = false,
    this.staticVoiceDescriptors = false,
    this.supportsInstructions = true,
    this.supportsStyle = true,
    this.localeHint = '留空自动识别，例如 Chinese、English',
    this.textLimit = 4000,
    this.maxUtf8Bytes,
    this.requiresAppId = false,
    this.supportsRole = true,
    this.modelLabel,
    this.apiKeyLabel,
    this.styleLabel = '风格',
    this.sourceSpeedRange = (min: 0.25, max: 4.0),
    this.prosodyRange = (min: 0.0, max: 2.0),
  });
  final String name, model, voice;
  final String localeHint;
  final List<String> formats, styles;
  final bool supportsSourceSpeed,
      supportsLocale,
      supportsProsody,
      requiresRegion,
      usesModel,
      usesSecretKey,
      remoteCatalog,
      staticVoiceDescriptors,
      supportsInstructions,
      supportsStyle;
  final int textLimit;
  final int? maxUtf8Bytes;
  final bool requiresAppId, supportsRole;
  final String? modelLabel, apiKeyLabel;
  final String styleLabel;
  final ({double min, double max}) sourceSpeedRange, prosodyRange;
}

const cloudTtsProviderProfiles = {
  'volcengine_v3': CloudTtsProviderProfile(
    name: '火山引擎（V3／豆包 2.0）',
    model: 'seed-tts-2.0',
    voice: 'zh_female_vv_uranus_bigtts',
    formats: ['mp3', 'ogg_opus', 'wav', 'pcm'],
    staticVoiceDescriptors: true,
    supportsSourceSpeed: true,
    supportsProsody: true,
    supportsRole: false,
    maxUtf8Bytes: 1024,
    modelLabel: '资源 ID',
    sourceSpeedRange: (min: 0.5, max: 2.0),
    prosodyRange: (min: 0.5, max: 2.0),
  ),
  'gemini_tts': CloudTtsProviderProfile(
    name: 'Gemini TTS',
    model: 'gemini-3.8-flash-tts',
    voice: 'Kore',
    formats: ['wav'],
    supportsRole: false,
  ),
  'volcengine': CloudTtsProviderProfile(
    name: '火山引擎（V1）',
    staticVoiceDescriptors: true,
    model: 'volcano_tts',
    voice: 'BV001_streaming',
    formats: ['mp3', 'ogg_opus', 'wav', 'pcm'],
    requiresAppId: true,
    supportsSourceSpeed: true,
    supportsProsody: true,
    supportsRole: false,
    supportsInstructions: false,
    maxUtf8Bytes: 1024,
    modelLabel: '业务集群',
    apiKeyLabel: 'Access Token',
    styleLabel: '情感',
    sourceSpeedRange: (min: 0.2, max: 3.0),
    prosodyRange: (min: 0.1, max: 3.0),
  ),
  'aws_polly': CloudTtsProviderProfile(
    name: 'AWS Polly',
    model: 'neural',
    voice: 'Zhiyu',
    formats: ['mp3', 'ogg_vorbis', 'wav', 'pcm'],
    requiresRegion: true,
    usesSecretKey: true,
    remoteCatalog: true,
    supportsLocale: true,
    supportsInstructions: false,
    supportsStyle: false,
    localeHint: '留空使用音色默认语言，例如 cmn-CN、en-US',
    textLimit: 3000,
  ),
  'azure_speech': CloudTtsProviderProfile(
    name: 'Azure Speech',
    remoteCatalog: true,
    model: '',
    voice: 'zh-CN-XiaoxiaoNeural',
    formats: ['mp3', 'wav', 'ogg', 'opus'],
    supportsSourceSpeed: true,
    supportsLocale: true,
    supportsProsody: true,
    requiresRegion: true,
    usesModel: false,
    supportsInstructions: false,
    localeHint: '留空按音色推断，例如 zh-CN、en-US',
  ),
  'openai_speech': CloudTtsProviderProfile(
    name: 'OpenAI Speech',
    supportsSourceSpeed: true,
    model: 'gpt-4o-mini-tts',
    voice: 'alloy',
    formats: ['mp3', 'opus', 'aac', 'flac', 'wav', 'pcm'],
  ),
  'alibaba_cloud': CloudTtsProviderProfile(
    name: '阿里云百炼',
    model: 'qwen3-tts-flash',
    voice: 'Cherry',
    formats: ['wav'],
    supportsLocale: true,
    textLimit: 600,
  ),
  'mimo': CloudTtsProviderProfile(
    name: 'Xiaomi MiMo',
    model: 'mimo-v2.5-tts',
    voice: 'mimo_default',
    formats: ['wav'],
    styles: ['开心', '悲伤', '愤怒', '惊讶', '恐惧', '厌恶', '小声', '平静'],
  ),
};
CloudTtsProviderProfile cloudTtsProfile(String provider) =>
    cloudTtsProviderProfiles[provider] ?? (throw StateError('云端 Provider 未支持'));
