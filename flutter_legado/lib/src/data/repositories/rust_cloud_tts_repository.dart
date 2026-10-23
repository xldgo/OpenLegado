import '../../domain/contracts/cloud_tts_provider.dart';
import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/cloud_tts_repository.dart';
import '../bridge/media_dto_mapping.dart';

final class RustCloudTtsRepository implements CloudTtsRepository {
  const RustCloudTtsRepository();
  @override
  Future<Map<String, CloudTtsCapabilities>> providerCapabilities() async {
    final values = await rustFuture(
      () => bridge.cloudTtsCapabilities(),
      operation: 'cloudTtsCapabilities',
    );
    return {
      for (final value in values)
        cloudProviderFromDto(value.provider): CloudTtsCapabilities(
          defaultModel: value.defaultModel,
          defaultVoice: value.defaultVoice,
          formats: value.formats,
          styles: value.styles,
          sampleRates: value.sampleRates,
          pcmSampleRates: value.pcmSampleRates,
          supportsSourceSpeed: value.supportsSourceSpeed,
          supportsLocale: value.supportsLocale,
          supportsProsody: value.supportsProsody,
          requiresRegion: value.requiresRegion,
          usesModel: value.usesModel,
          usesSecretKey: value.usesSecretKey,
          remoteCatalog: value.remoteCatalog,
          staticVoiceDescriptors: value.staticVoiceDescriptors,
          supportsInstructions: value.supportsInstructions,
          supportsStyle: value.supportsStyle,
          requiresAppId: value.requiresAppId,
          supportsRole: value.supportsRole,
          supportsSampleRate: value.supportsSampleRate,
          sourceSpeedRange: (
            min: value.sourceSpeedRange.min,
            max: value.sourceSpeedRange.max,
          ),
          prosodyRange: (
            min: value.prosodyRange.min,
            max: value.prosodyRange.max,
          ),
        ),
    };
  }

  @override
  Future<CloudTtsSpeechLimits> speechLimits(String provider) async {
    final value = await rustFuture(
      () => bridge.cloudTtsSpeechLimits(provider: cloudProviderToDto(provider)),
      operation: 'cloudTtsSpeechLimits',
    );
    return CloudTtsSpeechLimits(
      maxUtf16Units: value.maxUtf16Units,
      maxUtf8Bytes: value.maxUtf8Bytes,
    );
  }

  @override
  Future<CloudTtsEngine?> get(String id) async {
    final value = await rustFuture(
      () => bridge.cloudTtsGet(id: id),
      operation: 'cloudTtsGet',
    );
    return value == null ? null : cloudEngineFromDto(value);
  }

  @override
  Future<List<CloudTtsEngine>> list() async => (await rustFuture(
    () => bridge.cloudTtsList(),
    operation: 'cloudTtsList',
  )).map(cloudEngineFromDto).toList();
  @override
  Future<void> save(CloudTtsEngine engine) => rustFuture(
    () => bridge.cloudTtsSave(engine: cloudEngineToDto(engine)),
    operation: 'cloudTtsSave',
  );
  @override
  Future<void> delete(String id) async {
    if (!await rustFuture(
      () => bridge.cloudTtsDelete(id: id),
      operation: 'cloudTtsDelete',
    )) {
      throw StateError('云端引擎不存在');
    }
  }

  @override
  Future<List<String>> voices(String provider) async => (await rustFuture(
    () => bridge.cloudTtsVoices(provider: cloudProviderToDto(provider)),
    operation: 'cloudTtsVoices',
  )).map((v) => v.id).toList();
}
