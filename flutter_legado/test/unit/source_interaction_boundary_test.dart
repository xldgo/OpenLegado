import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fixtures/native_test_api.dart';

import 'package:flutter_legado/src/models/book_source.dart';
import 'package:flutter_legado/src/providers/source_interaction_provider.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('根装配共享四项能力，窄Provider可独立替换', () {
    final api = MockBookApi();
    final root = ProviderContainer(
      overrides: mergeTestOverrides([...api.overrides]),
    );
    addTearDown(root.dispose);
    expect(
      root.read(bookSourceEditServiceProvider),
      same(api.bookSourceEditService),
    );
    expect(
      root.read(sourceLoginV2ServiceProvider),
      same(api.sourceLoginV2Service),
    );
    expect(
      root.read(verificationServiceProvider),
      same(api.verificationService),
    );
    expect(
      root.read(webViewBridgeServiceProvider),
      same(api.webViewBridgeService),
    );
    final editor = BookSourceEditServiceMock();
    final login = SourceLoginV2ServiceMock();
    final verification = VerificationServiceMock();
    final web = WebViewBridgeServiceMock();
    final isolated = ProviderContainer(
      overrides: [
        bookSourceEditServiceProvider.overrideWithValue(editor),
        sourceLoginV2ServiceProvider.overrideWithValue(login),
        verificationServiceProvider.overrideWithValue(verification),
        webViewBridgeServiceProvider.overrideWithValue(web),
      ],
    );
    addTearDown(isolated.dispose);
    expect(isolated.read(bookSourceEditServiceProvider), same(editor));
    expect(isolated.read(sourceLoginV2ServiceProvider), same(login));
    expect(isolated.read(verificationServiceProvider), same(verification));
    expect(isolated.read(webViewBridgeServiceProvider), same(web));
    final injected = MockBookApi(
      bookSourceEditService: editor,
      sourceLoginV2Service: login,
      verificationService: verification,
      webViewBridgeService: web,
    );
    expect(injected.bookSourceEditService, same(editor));
    expect(injected.sourceLoginV2Service, same(login));
    expect(injected.verificationService, same(verification));
    expect(injected.webViewBridgeService, same(web));
    expect(createTestApplication(useMock: true), isA<MockBookApi>());
  });
  test('Mock保留空流、未命中与不执行真实JS的语义', () async {
    final api = MockBookApi();
    const source = BookSource(bookSourceUrl: 's', bookSourceName: '源');
    expect(
      await api.verificationService.verificationRequestStream().toList(),
      isEmpty,
    );
    expect(
      await api.verificationService.submitVerificationResult('k', 'code'),
      isFalse,
    );
    expect(
      await api.verificationService.cancelVerificationRequest('k'),
      isFalse,
    );
    expect(
      await api.webViewBridgeService.webviewRequestStream().toList(),
      isEmpty,
    );
    expect(
      await api.webViewBridgeService.submitWebviewResult('k', 'result'),
      isFalse,
    );
    expect(
      await api.webViewBridgeService.submitWebviewResultWithCookies(
        'k',
        'result',
        {},
      ),
      isFalse,
    );
    expect(await api.webViewBridgeService.cancelWebviewRequest('k'), isFalse);
    expect(await api.sourceLoginV2Service.isLoginUiV2(source), isFalse);
    expect((await api.sourceLoginV2Service.loadUi(source, {})).rows, isEmpty);
    expect(
      (await api.sourceLoginV2Service.execute(
        source,
        action: 'a',
        state: {},
        form: {},
      )).close,
      isTrue,
    );
    expect(
      (await api.bookSourceEditService.extractJsSource('script')).mainJs,
      'script',
    );
    expect(
      (await api.bookSourceEditService.checkJsSourceSyntax('')).valid,
      isFalse,
    );
  });
}
