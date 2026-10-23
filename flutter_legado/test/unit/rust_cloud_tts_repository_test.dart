import 'dart:typed_data';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/media_dto.dart';
import 'package:flutter_legado/src/data/repositories/rust_cloud_tts_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repository = RustCloudTtsRepository();
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('能力查询传递默认请求与编辑范围，失败不回退本地表', () async {
    when(() => bridge.crateFfiFfiCloudTtsCapabilities()).thenAnswer(
      (_) async => [
        CloudTtsCapabilitiesDto(
          provider: CloudTtsProviderDto.mimo,
          defaultModel: 'fixture-model',
          defaultVoice: 'fixture-voice',
          formats: ['wav'],
          styles: ['fixture-style'],
          sampleRates: Uint32List(0),
          pcmSampleRates: Uint32List(0),
          supportsSourceSpeed: true,
          supportsLocale: true,
          supportsProsody: false,
          requiresRegion: false,
          usesModel: true,
          usesSecretKey: false,
          remoteCatalog: false,
          staticVoiceDescriptors: false,
          supportsInstructions: true,
          supportsStyle: true,
          requiresAppId: false,
          supportsRole: false,
          supportsSampleRate: false,
          sourceSpeedRange: CloudTtsNumericRangeDto(min: 0.7, max: 1.4),
          prosodyRange: CloudTtsNumericRangeDto(min: 0, max: 2),
        ),
      ],
    );
    final capability = (await repository.providerCapabilities())['mimo']!;
    expect(
      (capability.defaultModel, capability.defaultVoice),
      ('fixture-model', 'fixture-voice'),
    );
    expect(capability.formats, ['wav']);
    expect(capability.sourceSpeedRange, (min: 0.7, max: 1.4));
    when(() => bridge.crateFfiFfiCloudTtsCapabilities())
        .thenThrow(StateError('读取失败'));
    await expectLater(repository.providerCapabilities(), throwsStateError);
  });

  test('分片限制按Provider查询并映射编码单位，失败继续抛出', () async {
    when(
      () => bridge.crateFfiFfiCloudTtsSpeechLimits(
        provider: CloudTtsProviderDto.volcengineV3,
      ),
    ).thenAnswer(
      (_) async =>
          const CloudTtsSpeechLimitsDto(maxUtf16Units: 120, maxUtf8Bytes: 256),
    );
    final limits = await repository.speechLimits('volcengine_v3');
    expect((limits.maxUtf16Units, limits.maxUtf8Bytes), (120, 256));
    when(
      () => bridge.crateFfiFfiCloudTtsSpeechLimits(
        provider: CloudTtsProviderDto.mimo,
      ),
    ).thenThrow(StateError('桥接失败'));
    await expectLater(repository.speechLimits('mimo'), throwsStateError);
    await expectLater(
      repository.speechLimits('unsupported'),
      throwsFormatException,
    );
  });
}
