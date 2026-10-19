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
    this.textLimit = 4000,
  });
  final String name, model, voice;
  final List<String> formats, styles;
  final bool supportsSourceSpeed, supportsLocale;
  final int textLimit;
}

const cloudTtsProviderProfiles = {
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
