import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/rss/presentation/rss_source_import_confirm_screen.dart';
import 'package:flutter_legado/src/features/rules/presentation/replace_rule_import_confirm_screen.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../fixtures/app_test_api.dart';
import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  setUp(() => SharedPreferences.setMockInitialValues({'rssSourceVersion': 6}));

  testWidgets('RSS默认选择新增和更新，等待写入时禁用确认并保留bool结果', (tester) async {
    final api = MockRustApi();
    final imported = Completer<int>();
    when(() => api.rssSourceRepository.getRssSources())
        .thenAnswer((_) async => []);
    when(() => api.rssSourceRepository.importRssSources(any()))
        .thenAnswer((_) => imported.future);
    Future<bool?>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...api.overrides]),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = RssSourceImportConfirmScreen.open(
                  context,
                  sources: [
                    {'sourceUrl': 'rss://new', 'sourceName': '新增源'},
                    {
                      'sourceUrl': 'rss://update',
                      'sourceName': '更新源',
                      'lastUpdateTime': 2,
                    },
                    {
                      'sourceUrl': 'rss://exists',
                      'sourceName': '已有源',
                      'lastUpdateTime': 1,
                    },
                  ],
                  localSources: const [
                    RssSource(
                      sourceUrl: 'rss://update',
                      sourceName: '本地更新源',
                      lastUpdateTime: 1,
                    ),
                    RssSource(
                      sourceUrl: 'rss://exists',
                      sourceName: '本地已有源',
                      lastUpdateTime: 1,
                    ),
                  ],
                );
              },
              child: const Text('打开导入'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开导入'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).map((w) => w.value),
      [true, true, false],
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    final payload =
        verify(() => api.rssSourceRepository.importRssSources(captureAny()))
                .captured
                .single
            as String;
    expect((jsonDecode(payload) as List).map((e) => e['sourceUrl']), [
      'rss://new',
      'rss://update',
    ]);
    imported.complete(2);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byType(RssSourceImportConfirmScreen), findsNothing);
  });

  testWidgets('替换规则默认只选新增，逐条失败不阻断后续并返回成功条数', (tester) async {
    final api = MockRustApi();
    when(() => api.replaceRuleRepository.getReplaceRules())
        .thenAnswer((_) async => []);
    when(() => api.replaceRuleRepository.addReplaceRule(any()))
        .thenAnswer((call) async {
          final rule = call.positionalArguments.single as ReplaceRule;
          if (rule.id == 2) throw StateError('单条失败夹具');
          return rule;
        });
    Future<int?>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...api.overrides]),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = ReplaceRuleImportConfirmScreen.open(
                  context,
                  raws: [
                    const ReplaceRule(
                      id: 1,
                      name: '更新规则',
                      pattern: 'new',
                    ).toJson(),
                    const ReplaceRule(
                      id: 2,
                      name: '失败规则',
                      pattern: 'bad',
                    ).toJson(),
                    const ReplaceRule(
                      id: 3,
                      name: '成功规则',
                      pattern: 'ok',
                    ).toJson(),
                  ],
                  localRules: const [
                    ReplaceRule(id: 1, name: '本地规则', pattern: 'old'),
                  ],
                );
              },
              child: const Text('打开导入'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开导入'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).map((w) => w.value),
      [false, true, true],
    );
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(await result, 1);
    verify(() => api.replaceRuleRepository.addReplaceRule(any())).called(2);
    verifyNever(() => api.replaceRuleRepository.updateReplaceRule(any()));
  });
}
