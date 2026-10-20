import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/data/services/source_login_service.dart';
import 'package:flutter_legado/src/features/book_sources/source_login_providers.dart';
import 'package:flutter_legado/src/features/book_sources/presentation/source_login_screen.dart';

import '../mocks/mocks.dart';

void main() {
  late SourceLoginRepositoryMock repository;
  late SourceLoginService service;
  setUp(() {
    repository = SourceLoginRepositoryMock();
    when(() => repository.getLoginInfo(any())).thenAnswer((_) async => '');
    when(() => repository.getLoginHeader(any())).thenAnswer((_) async => '');
    when(() => repository.putLoginHeader(any(), any()))
        .thenAnswer((_) async {});
    when(() => repository.putLoginInfo(any(), any())).thenAnswer((_) async {});
    service = SourceLoginService(
      repository: repository,
      readLegacy: (_) async => null,
      clearLegacy: (_) async {},
    );
  });

  Future<void> pump(WidgetTester tester, Widget home) => tester.pumpWidget(
    ProviderScope(
      overrides: [sourceLoginServiceProvider.overrideWithValue(service)],
      child: MaterialApp(home: home),
    ),
  );

  testWidgets('同一页面切换 A/B 源，空 B 清空原凭据与输入框', (tester) async {
    final url = ValueNotifier('A');
    addTearDown(url.dispose);
    when(() => repository.getLoginInfo('A'))
        .thenAnswer((_) async => '{"token":"A-secret"}');
    await pump(
      tester,
      ValueListenableBuilder<String>(
        valueListenable: url,
        builder: (_, value, _) =>
            SourceLoginScreen(sourceUrl: value, sourceName: value),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'A-secret',
    );
    url.value = 'B';
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '',
    );
    expect(find.text('A-secret'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载期间输入不会被迟到 Token 回填覆盖', (tester) async {
    final gate = Completer<String>();
    when(() => repository.getLoginInfo('A')).thenAnswer((_) => gate.future);
    await pump(
      tester,
      const SourceLoginScreen(sourceUrl: 'A', sourceName: 'A'),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'new draft');
    gate.complete('{"token":"old saved"}');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'new draft',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存成功先关闭等待层，登录路由返回 true', (tester) async {
    bool? result;
    await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      const SourceLoginScreen(sourceUrl: 'A', sourceName: 'A'),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, ' token ');
    await tester.tap(find.text('保存登录信息'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(SourceLoginScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    verify(() => repository.putLoginInfo('A', '{"token":"token"}')).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存失败关闭等待层并保留页面、输入和重试能力', (tester) async {
    when(() => repository.putLoginInfo(any(), any()))
        .thenThrow(StateError('拒绝写入'));
    await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const SourceLoginScreen(sourceUrl: 'A', sourceName: 'A'),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'draft');
    await tester.tap(find.text('保存登录信息'));
    await tester.pumpAndSettle();
    expect(find.byType(SourceLoginScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'draft',
    );
    when(() => repository.putLoginInfo(any(), any())).thenAnswer((_) async {});
    await tester.tap(find.text('保存登录信息'));
    await tester.pumpAndSettle();
    expect(find.byType(SourceLoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
