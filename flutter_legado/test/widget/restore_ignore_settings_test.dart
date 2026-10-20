import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/constants/pref_keys.dart';
import 'package:flutter_legado/src/data/repositories/preferences_restore_ignore_repository.dart';
import 'package:flutter_legado/src/domain/contracts/restore_ignore_repository.dart';
import 'package:flutter_legado/src/domain/models/restore_ignore_config.dart';
import 'package:flutter_legado/src/providers/restore_ignore_provider.dart';
import 'package:flutter_legado/src/features/settings/presentation/webdav_settings_screen.dart';
import 'package:flutter_legado/src/widgets/restore_ignore_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

class _ControlledRepository implements RestoreIgnoreRepository {
  late final delegate = PreferencesRestoreIgnoreRepository();
  bool failLoad = false;
  bool failSave = false;
  int saveCalls = 0;

  @override
  Future<RestoreIgnoreConfig> load() {
    if (failLoad) throw StateError('恢复忽略项读取失败，请重试');
    return delegate.load();
  }

  @override
  Future<void> save(RestoreIgnoreConfig config) {
    saveCalls++;
    if (failSave) throw StateError('模拟保存失败');
    return delegate.save(config);
  }
}

void main() {
  late _ControlledRepository repository;
  late MockRustApi api;
  const initial = '{"readConfig":true,"localBook":true}';

  setUpAll(registerFallbacks);
  setUp(() {
    SharedPreferences.setMockInitialValues({
      PrefKeys.restoreIgnore: initial,
      'app_backup_path': 'E:/备份',
    });
    repository = _ControlledRepository();
    api = MockRustApi();
  });

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...api.overrides,
          restoreIgnoreRepositoryProvider.overrideWithValue(repository),
        ]),
        child: const MaterialApp(home: WebDavSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('恢复忽略列表'), 150);
    await tester.pumpAndSettle();
  }

  Future<void> openIgnore(WidgetTester tester) async {
    await tester.tap(find.text('恢复忽略列表'));
    await tester.pumpAndSettle();
  }

  bool checked(WidgetTester tester, String title) => tester
      .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, title))
      .value!;

  testWidgets('八项标题和顺序保持，取消草稿不保存，再开恢复已保存值', (tester) async {
    await openScreen(tester);
    await openIgnore(tester);
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .map((row) => (row.title! as Text).data),
      ['阅读界面配置', '主题模式', '主题配置', '封面规则', '书架布局', '显示订阅', '线程数', '本地书籍'],
    );
    expect(checked(tester, '阅读界面配置'), isTrue);
    expect(checked(tester, '主题模式'), isFalse);
    expect(checked(tester, '本地书籍'), isTrue);
    await tester.tap(find.text('阅读界面配置'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 0);
    expect(
      (await SharedPreferences.getInstance()).getString(PrefKeys.restoreIgnore),
      initial,
    );
    await openIgnore(tester);
    expect(checked(tester, '阅读界面配置'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('确定保存成功才显示反馈，再开显示已保存选择', (tester) async {
    await openScreen(tester);
    await openIgnore(tester);
    await tester.tap(find.text('主题模式'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('已保存恢复忽略项').hitTestable(), findsOneWidget);
    expect(repository.saveCalls, 1);
    expect((await repository.load())['themeMode'], isTrue);
    await openIgnore(tester);
    expect(checked(tester, '主题模式'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存失败不假成功，再开显示旧值且可重试', (tester) async {
    repository.failSave = true;
    await openScreen(tester);
    await openIgnore(tester);
    await tester.tap(find.text('阅读界面配置'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('恢复忽略项保存失败，请重试').hitTestable(), findsOneWidget);
    expect(find.text('已保存恢复忽略项'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString(PrefKeys.restoreIgnore),
      initial,
    );
    await openIgnore(tester);
    expect(checked(tester, '阅读界面配置'), isTrue);
    repository.failSave = false;
    await tester.tap(find.text('阅读界面配置'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect((await repository.load())['readConfig'], isFalse);
    expect(repository.saveCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('读取失败提示且不打开全false草稿，恢复读取后可重试', (tester) async {
    repository.failLoad = true;
    await openScreen(tester);
    await openIgnore(tester);
    expect(find.text('恢复忽略项读取失败，请重试').hitTestable(), findsOneWidget);
    expect(find.byType(RestoreIgnoreDialog), findsNothing);
    expect(repository.saveCalls, 0);
    repository.failLoad = false;
    await openIgnore(tester);
    expect(checked(tester, '阅读界面配置'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('本地备份读取忽略策略失败即中止，不调用备份或提示成功', (tester) async {
    repository.failLoad = true;
    await openScreen(tester);
    await tester.ensureVisible(find.text('备份'));
    await tester.tap(find.text('备份'));
    await tester.pumpAndSettle();
    expect(find.textContaining('恢复忽略项读取失败').hitTestable(), findsOneWidget);
    expect(find.textContaining('备份成功'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => api.backupRepository.backup(any()));
    expect(tester.takeException(), isNull);
  });
}
