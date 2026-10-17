import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/domain/models/source_syntax_result.dart';
import 'package:flutter_legado/src/domain/models/login_v2.dart';
import 'package:flutter_legado/src/features/book_sources/js_source_edit_screen.dart';
import 'package:flutter_legado/src/models/book_source.dart';
import 'package:flutter_legado/src/features/tools/presentation/curl_analyze_url_sheet.dart';
import 'package:flutter_legado/src/utils/source_login_entry.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  testWidgets('cURL转换仅依赖编辑服务，结果可插入并保持原错误文案', (tester) async {
    final service = BookSourceEditServiceMock();
    when(() => service.looksLikeCurl('curl -L https://source.test'))
        .thenAnswer((_) async => true);
    when(() => service.curlToAnalyzeUrl('curl -L https://source.test'))
        .thenAnswer((_) async => 'https://source.test');
    String? inserted;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bookSourceEditServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  inserted = await CurlAnalyzeUrlSheet.show(
                    context,
                    initialText: 'curl -L https://source.test',
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('转换'));
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.last.controller!.text, 'https://source.test');
    await tester.tap(find.text('插入'));
    await tester.pumpAndSettle();
    expect(inserted, 'https://source.test');
    expect(tester.takeException(), isNull);
  });
  testWidgets('JS编辑语法提示与保存走窄依赖，保存当前完整脚本', (tester) async {
    final editor = BookSourceEditServiceMock();
    final repository = MockRustApi().bookSourceRepository;
    const source = BookSource(
      bookSourceUrl: 'https://source.test',
      bookSourceName: '测试源',
      mainJs: '当前脚本',
    );
    when(() => editor.checkJsSourceSyntax('当前脚本')).thenAnswer(
      (_) async =>
          const SourceSyntaxResult(valid: false, message: '缺少括号', line: 2),
    );
    when(() => editor.extractJsSource('当前脚本')).thenAnswer((_) async => source);
    when(() => repository.getBookSources()).thenAnswer((_) async => []);
    when(
      () => repository.addBookSource(any()),
    ).thenAnswer((call) async => call.positionalArguments.single as BookSource);
    bool? saved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookSourceEditServiceProvider.overrideWithValue(editor),
          bookSourceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const JsSourceEditScreen(),
                    ),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '当前脚本');
    await tester.tap(find.byTooltip('语法检查'));
    await tester.pumpAndSettle();
    expect(find.textContaining('语法警告 L2'), findsWidgets);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    final actual =
        verify(() => repository.addBookSource(captureAny())).captured.single
            as BookSource;
    expect(actual.mainJs, '当前脚本');
    expect(actual.bookSourceUrl, 'https://source.test');
    expect(tester.takeException(), isNull);
  });
  testWidgets('书源登录入口选择V2窄服务，动作带表单并正常关闭', (tester) async {
    final service = SourceLoginV2ServiceMock();
    const source = BookSource(
      bookSourceUrl: 'https://source.test',
      bookSourceName: '测试源',
    );
    when(() => service.isLoginUiV2(source)).thenAnswer((_) async => true);
    when(() => service.loadUi(source, any())).thenAnswer(
      (_) async => LoginUiDescription(
        rows: const [
          LoginUiRow(type: 'text', key: 'account', name: '账号'),
          LoginUiRow(type: 'button', name: '登录', action: 'login'),
        ],
      ),
    );
    when(
      () => service.execute(
        source,
        action: 'login',
        state: any(named: 'state'),
        form: any(named: 'form'),
      ),
    ).thenAnswer((call) async {
      expect(call.namedArguments[#form], {'account': '账号甲'});
      return LoginActionResult(login: {'ok': true});
    });
    bool? loggedIn;
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...MockRustApi().overrides,
          sourceLoginV2ServiceProvider.overrideWithValue(service),
        ]),
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  loggedIn = await showSourceLogin(context, ref, source);
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '账号甲');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(loggedIn, isTrue);
    expect(tester.takeException(), isNull);
  });
}
