import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../domain/contracts/locale_settings_repository.dart';
import 'locale_settings_provider.dart';
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

/// 语言偏好的界面投影，沿用现有系统语言解析。— Codex + UI
class AppLocaleNotifier extends Notifier<String> {
  int _generation = 0;
  @override
  String build() {
    final repository = ref.watch(localeSettingsRepositoryProvider);
    final generation = ++_generation;
    final subscription = repository.watch().listen(
      (_) => _publish(repository, generation),
    );
    ref.onDispose(() => unawaited(subscription.cancel()));
    unawaited(
      Future.microtask(() async {
        if (!ref.mounted || generation != _generation) return;
        try {
          await repository.load();
          _publish(repository, generation);
        } catch (error) {
          debugPrint('语言设置读取失败，可重新加载：$error');
        }
      }),
    );
    return repository.current.locale;
  }

  void _publish(LocaleSettingsRepository repository, int generation) {
    if (!ref.mounted || generation != _generation) return;
    final next = repository.current.locale;
    if (state != next) state = next;
  }

  Future<void> setLocale(String locale) async {
    final repository = ref.read(localeSettingsRepositoryProvider);
    final generation = _generation;
    try {
      final saving = repository.update(locale: locale);
      _publish(repository, generation);
      await saving;
    } finally {
      _publish(repository, generation);
    }
  }

  Future<void> reload() async {
    final repository = ref.read(localeSettingsRepositoryProvider);
    final generation = _generation;
    await repository.reload();
    _publish(repository, generation);
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, String>(
  AppLocaleNotifier.new,
);
