import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_locale_settings_repository.dart';
import '../domain/contracts/locale_settings_repository.dart';
import 'app_settings_provider.dart';
import '../l10n/generated/app_localizations.dart';

final localeSettingsRepositoryProvider = Provider<LocaleSettingsRepository>(
  (ref) => AppLocaleSettingsRepository(
    ref.watch(appSettingsServiceProvider),
    supportedLanguages: AppLocalizations.supportedLocales.map(
      (locale) => locale.languageCode,
    ),
  ),
);
