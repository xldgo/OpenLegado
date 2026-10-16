import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/data/services/mock_http_tts_synthesizer.dart';
import 'package:flutter_legado/src/data/services/rust_http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/features/read_aloud/tts_providers.dart';
import 'package:flutter_legado/src/platform/tts/system_tts.dart';
import 'package:flutter_legado/src/platform/tts/system_tts_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _System extends Mock implements SystemTts {}

void main() {
  test('根装配选择正式或 Mock 合成，不初始化原生或系统插件', () async {
    expect(
      createTestApplication(useMock: false).httpTtsSynthesizer,
      isA<RustHttpTtsSynthesizer>(),
    );
    final api = createTestApplication(useMock: true);
    expect(api.httpTtsSynthesizer, isA<MockHttpTtsSynthesizer>());
    final result = await api.httpTtsSynthesizer.synthesize(
      engineId: 1,
      text: '正文',
      engineUrl: 'http://tts',
    ) as HttpTtsNoAudio;
    expect(result.reason, HttpTtsNoAudioReason.mock);
    final container = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(container.dispose);
    expect(
      container.read(httpTtsSynthesizerProvider),
      same(api.httpTtsSynthesizer),
    );
    expect(container.read(systemTtsServiceProvider), isA<SystemTtsService>());
  });

  test('依赖替换后 HTTP 跟随新装配，系统接口保持同一实例', () {
    final container = ProviderContainer(
      overrides: [
        httpTtsSynthesizerProvider.overrideWithValue(
          MockBookApi().httpTtsSynthesizer,
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      httpTtsSynthesizerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final first = container.read(httpTtsSynthesizerProvider);
    final system = container.read(systemTtsServiceProvider);
    final second = MockBookApi(
      httpTtsSynthesizer: const RustHttpTtsSynthesizer(),
    );
    container.updateOverrides(
      mergeTestOverrides([
        httpTtsSynthesizerProvider.overrideWithValue(second.httpTtsSynthesizer),
      ]),
    );
    expect(
      container.read(httpTtsSynthesizerProvider),
      same(second.httpTtsSynthesizer),
    );
    expect(container.read(httpTtsSynthesizerProvider), isNot(same(first)));
    expect(container.read(systemTtsServiceProvider), same(system));
  });

  test('系统能力可仅覆盖接口，HTTP 注入不依赖系统实现', () {
    final fake = _System();
    when(() => fake.isSupported).thenReturn(true);
    final container = ProviderContainer(
      overrides: [systemTtsServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    expect(container.read(systemTtsServiceProvider), same(fake));
    expect(container.read(systemTtsServiceProvider).isSupported, isTrue);
    verify(() => fake.isSupported).called(1);
    verifyNoMoreInteractions(fake);
  });
}
