import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../services/settings_service.dart';
import '../l10n/generated/app_localizations.dart';

const appSupportedLocales = AppLocalizations.supportedLocales;

String _normalizeLocale(String value) {
  final language = value.replaceAll('_', '-').split('-').first;
  return appSupportedLocales.any((locale) => locale.languageCode == language)
      ? language
      : 'system';
}

/// 应用文案与设计库组件共用语言解析，未支持的系统语言回退中文。
Locale resolveAppLocale(String preference, List<Locale> systemLocales) {
  final language = _normalizeLocale(preference);
  if (language != 'system') return Locale(language);
  for (final locale in systemLocales) {
    if (appSupportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    )) {
      return Locale(locale.languageCode);
    }
  }
  return appSupportedLocales.first;
}

/// 保存语言选择并通知应用入口，启动恢复不能覆盖期间的用户操作。
class AppLocaleNotifier extends Notifier<String> {
  final _settings = SettingsService();
  int _generation = 0;

  @override
  String build() {
    final generation = _generation;
    Future.microtask(() => _load(generation));
    return 'system';
  }

  Future<void> _load(int generation) async {
    final locale = await _settings.getLocale();
    if (!ref.mounted || generation != _generation) return;
    state = _normalizeLocale(locale);
  }

  Future<void> setLocale(String locale) async {
    final selection = _normalizeLocale(locale);
    _generation++;
    state = selection;
    await _settings.setLocale(selection);
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, String>(
  AppLocaleNotifier.new,
);
