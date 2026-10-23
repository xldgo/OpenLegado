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
