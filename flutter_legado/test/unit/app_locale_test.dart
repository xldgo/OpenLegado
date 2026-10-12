import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/providers/app_locale_notifier.dart';
import 'package:flutter_legado/src/l10n/generated/app_localizations.dart';
import 'package:flutter_legado/src/l10n/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('跟随系统选择支持的语言，其他语言回退中文', () {
    expect(
      resolveAppLocale('system', [const Locale('zh', 'CN')]),
      const Locale('zh'),
    );
    expect(
      resolveAppLocale('system', [const Locale('en', 'US')]),
      const Locale('en'),
    );
    expect(
      resolveAppLocale('system', [const Locale('ja')]),
      const Locale('zh'),
    );
    expect(resolveAppLocale('system', []), const Locale('zh'));
  });

  test('显式语言优先于系统，兼容旧的地区格式', () {
    expect(resolveAppLocale('zh_CN', [const Locale('en')]), const Locale('zh'));
    expect(resolveAppLocale('en-US', [const Locale('zh')]), const Locale('en'));
  });

  test('语言选择即时更新并在冷启动时恢复', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(appLocaleProvider), 'system');
    await container.read(appLocaleProvider.notifier).setLocale('en');
    expect(container.read(appLocaleProvider), 'en');
    expect(
      (await SharedPreferences.getInstance()).getString('app_locale'),
      'en',
    );

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    restarted.read(appLocaleProvider);
    await Future<void>.delayed(Duration.zero);
    expect(restarted.read(appLocaleProvider), 'en');
  });

  test('ARB 代理加载主入口文案与英文复数单位', () async {
    final zh = await AppLocalizations.delegate.load(const Locale('zh'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(zh.home, '首页');
    expect(zh.my, '我的');
    expect(zh.bookCount(2), '2 本');
    expect(en.home, 'Home');
    expect(en.my, 'Me');
    expect(en.bookCount(1), '1 book');
    expect(en.bookCount(2), '2 books');
    expect(en.minuteCount(1), '1 minute');
    expect(en.minuteCount(2), '2 minutes');
    expect(en.gridColumnCount(3), 'Grid (3 columns)');
    expect(AppLocalizations.supportedLocales.first, const Locale('zh'));
  });

  test('旧页面兼容入口与 ARB 使用同一份文案', () {
    addTearDown(() => AppStrings.setLocale('zh'));
    AppStrings.setLocale('en');
    expect(AppStrings.my, lookupAppLocalizations(const Locale('en')).my);
    expect(AppStrings.bookshelf, 'Bookshelf');
    AppStrings.setLocale('zh');
    expect(AppStrings.my, '我的');
  });

  test('独立 Material 与 Cupertino 的中文返回文案均可加载', () async {
    final material = await GlobalMaterialLocalizations.delegate.load(
      const Locale('zh'),
    );
    final cupertino = await GlobalCupertinoLocalizations.delegate.load(
      const Locale('zh'),
    );
    expect(material.backButtonTooltip, '返回');
    expect(cupertino.backButtonLabel, '返回');
  });
}
