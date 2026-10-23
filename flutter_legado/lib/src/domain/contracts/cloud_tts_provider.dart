/// 云端引擎/音色编辑使用的能力快照，由Rust返回。— Codex + Bridge
final class CloudTtsCapabilities {
  const CloudTtsCapabilities({
    required this.defaultModel,
    required this.defaultVoice,
    required this.formats,
    required this.styles,
    required this.supportsSourceSpeed,
    required this.supportsLocale,
    required this.supportsProsody,
    required this.requiresRegion,
    required this.usesModel,
    required this.usesSecretKey,
    required this.remoteCatalog,
    required this.staticVoiceDescriptors,
    required this.supportsInstructions,
    required this.supportsStyle,
    required this.requiresAppId,
    required this.supportsRole,
    required this.supportsSampleRate,
    required this.sourceSpeedRange,
    required this.prosodyRange,
    required this.sampleRates,
    required this.pcmSampleRates,
  });
  final String defaultModel, defaultVoice;
  final List<String> formats, styles;
  final List<int> sampleRates, pcmSampleRates;
  final bool supportsSourceSpeed,
      supportsLocale,
      supportsProsody,
      requiresRegion,
      usesModel,
      usesSecretKey,
      remoteCatalog,
      staticVoiceDescriptors,
      supportsInstructions,
      supportsStyle,
      requiresAppId,
      supportsRole,
      supportsSampleRate;
  final ({double min, double max}) sourceSpeedRange, prosodyRange;
}
