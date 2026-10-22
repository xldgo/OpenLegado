import '../fixtures/app_test_api.dart';

// SourceLoginScreen widget 测试
//
// 回归：全局 TabBarTheme.tabAlignment=start 对非 scrollable TabBar 断言失败
// 红屏（"TabAlignment.start is only valid for scrollable tab bars"）。
// 登录页 TabBar 须显式 tabAlignment: fill（2026-08-14 登录红屏修复）。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/features/book_sources/presentation/source_login_screen.dart';

import '../mocks/mocks.dart';

void main() {
  late MockRustApi mockApi;

  setUpAll(registerFallbacks);

  setUp(() {
    mockApi = MockRustApi();
    when(() => mockApi.sourceLoginRepository.getLoginInfo(any()))
        .thenAnswer((_) async => '');
    when(() => mockApi.sourceLoginRepository.getLoginHeader(any()))
        .thenAnswer((_) async => '');
    when(() => mockApi.configRepository.getConfig(any()))
        .thenAnswer((_) async => null);
  });

  testWidgets('登录页 TabBar 渲染无断言红屏（tabAlignment.fill）', (tester) async {
    Future<bool?>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...mockApi.overrides]),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = SourceLoginScreen.open(
                  context,
                  sourceUrl: 'https://a.com',
                  sourceName: '测试源',
                  loginUrl: 'https://a.com/login',
                );
              },
              child: const Text('打开登录'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开登录'));
    await tester.pumpAndSettle();

    // TabBar 两页签 + 手动输入表单正常渲染，无异常
    // 普通路由的大顶栏包含展开/折叠标题，实际登录页仍只有一个。
    expect(find.byType(SourceLoginScreen), findsOneWidget);
    expect(find.text('登录 - 测试源'), findsWidgets);
    expect(find.text('手动输入'), findsOneWidget);
    expect(find.text('登录链接'), findsOneWidget);
    expect(find.text('保存登录信息'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(SourceLoginScreen))).pop(true);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}
