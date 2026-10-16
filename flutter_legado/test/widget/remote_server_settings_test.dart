import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/contracts/remote_server_repository.dart';
import 'package:flutter_legado/src/domain/models/remote_server_config.dart';
import 'package:flutter_legado/src/providers/remote_book/remote_server_provider.dart';
import 'package:flutter_legado/src/screens/remote_book_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

class _MockServerRepository extends Mock implements RemoteServerRepository {}

void main() {
  const server = RemoteServerConfig(
    id: 1,
    name: '服务器一',
    url: 'https://one.example',
  );
  late _MockServerRepository repository;
  late MockRustApi api;

  setUpAll(() {
    registerFallbacks();
    registerFallbackValue(server);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _MockServerRepository();
    api = MockRustApi();
    when(() => repository.load())
        .thenAnswer((_) async => RemoteServerSnapshot(servers: [server]));
    when(() => api.webDavService.webdavListDir(any(), any()))
        .thenAnswer((_) async => const []);
    when(() => api.bookshelfRepository.getBooks()).thenAnswer((_) async => []);
  });

  Future<void> open(WidgetTester tester, {bool sheet = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...api.overrides,
          remoteServerRepositoryProvider.overrideWithValue(repository),
        ]),
        child: const MaterialApp(home: RemoteBookScreen()),
      ),
    );
    await tester.pumpAndSettle();
    if (!sheet) return;
    await tester.tap(find.byIcon(Symbols.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('服务器配置'));
    await tester.pumpAndSettle();
  }

  void expectVisibleError(String message) {
    expect(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.text(message),
          )
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
  }

  testWidgets('初始读取失败由顶层对话框提示，不产生未捕获异常', (tester) async {
    when(() => repository.load()).thenThrow(StateError('模拟读取失败'));
    await open(tester, sheet: false);
    expect(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.text('服务器配置读取失败，请重试'),
          )
          .hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('选择失败在sheet上方显示错误，关闭错误仍可重试选择', (tester) async {
    when(() => repository.select(1)).thenThrow(StateError('模拟选择失败'));
    await open(tester);
    await tester.tap(find.text('服务器一'));
    await tester.pumpAndSettle();
    expectVisibleError('服务器切换失败，请重试');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
      defaultRemoteServerId,
    );
    when(() => repository.select(1)).thenAnswer(
      (_) async => RemoteServerSnapshot(servers: [server], selectedId: 1),
    );
    await tester.tap(find.text('服务器一'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新增失败错误可见，列表保持已保存服务器', (tester) async {
    when(() => repository.save(any())).thenThrow(StateError('模拟保存失败'));
    await open(tester);
    await tester.tap(find.byTooltip('添加'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '未保存新增');
    await tester.enterText(fields.at(1), 'https://new.example');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expectVisibleError('服务器配置保存失败，请重试');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('未保存新增'), findsNothing);
    expect(find.text('服务器一'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('编辑失败错误可见，再编辑仍显示已保存值', (tester) async {
    when(() => repository.save(any())).thenThrow(StateError('模拟保存失败'));
    await open(tester);
    await tester.tap(find.byIcon(Symbols.edit_rounded));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, '未保存修改');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expectVisibleError('服务器配置保存失败，请重试');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('服务器一'), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.edit_rounded));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.first).controller!.text, '服务器一');
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除失败错误在sheet上方可见且保留原列表', (tester) async {
    when(() => repository.delete(1)).thenThrow(StateError('模拟删除失败'));
    await open(tester);
    await tester.tap(find.byIcon(Symbols.delete_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expectVisibleError('服务器删除失败，请重试');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('服务器一'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
