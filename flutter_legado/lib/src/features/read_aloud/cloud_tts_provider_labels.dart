/// 名称、标签及提示属于界面；默认请求与能力从Rust获取。— Codex + UI
final class CloudTtsProviderLabels {
  const CloudTtsProviderLabels(
    this.name, {
    this.localeHint = '留空自动识别，例如 Chinese、English',
    this.modelLabel,
    this.apiKeyLabel,
    this.styleLabel = '风格',
  });
  final String name, localeHint, styleLabel;
  final String? modelLabel, apiKeyLabel;
}

const cloudTtsProviderLabels = {
  'volcengine_v3': CloudTtsProviderLabels(
    '火山引擎（V3／豆包 2.0）',
    modelLabel: '资源 ID',
  ),
  'gemini_tts': CloudTtsProviderLabels('Gemini TTS'),
  'volcengine': CloudTtsProviderLabels(
    '火山引擎（V1）',
    modelLabel: '业务集群',
    apiKeyLabel: 'Access Token',
    styleLabel: '情感',
  ),
  'aws_polly': CloudTtsProviderLabels(
    'AWS Polly',
    localeHint: '留空使用音色默认语言，例如 cmn-CN、en-US',
  ),
  'azure_speech': CloudTtsProviderLabels(
    'Azure Speech',
    localeHint: '留空按音色推断，例如 zh-CN、en-US',
  ),
  'openai_speech': CloudTtsProviderLabels('OpenAI Speech'),
  'alibaba_cloud': CloudTtsProviderLabels('阿里云百炼'),
  'mimo': CloudTtsProviderLabels('Xiaomi MiMo'),
};
