import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_theme_colors_settings_repository.dart';
import '../../domain/contracts/theme_colors_settings_repository.dart';
import '../app_settings_provider.dart';

final themeColorsSettingsRepositoryProvider =
    Provider<ThemeColorsSettingsRepository>(
      (ref) => AppThemeColorsSettingsRepository(
        ref.watch(appSettingsServiceProvider),
      ),
    );
