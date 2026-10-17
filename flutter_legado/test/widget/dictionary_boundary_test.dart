import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_legado/src/data/repositories/mock_dict_rule_repository.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_legado/src/providers/dictionary_provider.dart';
import 'package:flutter_legado/src/routes.dart';
import 'package:flutter_legado/src/features/rules/presentation/dict_rule_screen.dart';
import 'package:flutter_legado/src/features/dictionary/presentation/dict_screen.dart';
import 'package:flutter_legado/src/widgets/dict_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  testWidgets('管理页禁用规则后返回查询页，在线入口使用同一仓储最新配置', (tester) async {
    final repository = MockDictRuleRepository();
    final service = DictionaryServiceMock();
    when(() => service.dictLookup('chapter')).thenAnswer(
      (_) async => const DictEntry(word: 'chapter', definitions: ['章节释义']),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictRuleRepositoryProvider.overrideWithValue(repository),
          dictionaryServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: const DictScreen(),
          routes: {AppRoutes.dictRule: (_) => const DictRuleScreen()},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Chapter');
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(find.text('章节释义'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '海词中文'), findsOneWidget);
    await tester.tap(find.byTooltip('规则管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect((await repository.dictRuleList()).first.enabled, isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, '海词中文'), findsNothing);
    expect(find.widgetWithText(ActionChip, '海词英文'), findsOneWidget);
    expect(find.text('章节释义'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选词面板只为启用规则建立在线页签', (tester) async {
    final repository = MockDictRuleRepository();
    final first = (await repository.dictRuleList()).first;
    await repository.dictRuleSetEnabled(id: first.id, enabled: false);
    final service = DictionaryServiceMock();
    when(() => service.dictLookup('chapter'))
        .thenAnswer((_) async => const DictEntry(word: 'chapter'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictRuleRepositoryProvider.overrideWithValue(repository),
          dictionaryServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DictDialog(word: 'chapter')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, '海词中文'), findsNothing);
    expect(find.widgetWithText(Tab, '海词英文'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(5));
    expect(find.text('本地词典未收录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('启停返回false回滚开关，不显示成功', (tester) async {
    final repository = DictRuleRepositoryMock();
    when(() => repository.dictRuleList()).thenAnswer(
      (_) async => [const DictRule(id: 7, name: '保留词典', enabled: false)],
    );
    when(() => repository.dictRuleSetEnabled(id: 7, enabled: true))
        .thenAnswer((_) async => false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dictRuleRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: DictRuleScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.textContaining('启用/禁用失败'), findsOneWidget);
    expect(find.text('保留词典'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('查询失败展示错误，不伪装成未收录', (tester) async {
    final service = DictionaryServiceMock();
    when(() => service.dictLookup('chapter')).thenThrow(StateError('查询网络失败'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictRuleRepositoryProvider.overrideWithValue(
            MockDictRuleRepository(),
          ),
          dictionaryServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: DictScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'chapter');
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(find.textContaining('查询网络失败'), findsOneWidget);
    expect(find.textContaining('未收录'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
