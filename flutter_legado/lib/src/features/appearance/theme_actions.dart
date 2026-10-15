import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/theme_colors_settings.dart';
import '../../data/repositories/preferences_theme_preset_repository.dart';
import '../../domain/contracts/theme_preset_repository.dart';
import '../../models/theme_document.dart';
import '../../models/theme_preset.dart';
import '../../platform/files/theme_file_service.dart';
import '../../providers/theme/theme_colors_notifier.dart';
import '../../providers/theme/theme_notifier.dart';

final themePresetRepositoryProvider = Provider<ThemePresetRepository>(
  (ref) => PreferencesThemePresetRepository(),
);
final themeFileServiceProvider = Provider<ThemeFileService>(
  (ref) => ThemeFileService(),
);
final themeActionsProvider = Provider<ThemeActions>((ref) => ThemeActions(ref));

/// 外观交互编排，不保存第二份配色状态，不依赖页面上下文。
class ThemeActions {
  ThemeActions(this._ref);

  final Ref _ref;

  Future<List<ThemePreset>> readPresets() =>
      _ref.read(themePresetRepositoryProvider).readAll();

  Future<List<ThemePreset>> removePresetAt(int index) =>
      _ref.read(themePresetRepositoryProvider).removeAt(index);

  Future<void> savePreset(String name, {required bool isNight}) {
    final colors = _ref.read(themeColorsProvider);
    return _ref
        .read(themePresetRepositoryProvider)
        .add(
          ThemePreset(
            name: name,
            isNight: isNight,
            primary: isNight ? colors.primaryNight : colors.primary,
            accent: isNight ? colors.accentNight : colors.accent,
            background: isNight ? colors.backgroundNight : colors.background,
            bottomBackground: isNight
                ? colors.bottomBackgroundNight
                : colors.bottomBackground,
          ),
        );
  }

  Future<void> applyPreset(ThemePreset preset) =>
      _ref.read(themeColorsProvider.notifier).applyColors({
        preset.isNight ? ThemeColorRole.primaryNight : ThemeColorRole.primary:
            preset.primary,
        preset.isNight ? ThemeColorRole.accentNight : ThemeColorRole.accent:
            preset.accent,
        preset.isNight
                ? ThemeColorRole.backgroundNight
                : ThemeColorRole.background:
            preset.background,
        preset.isNight
                ? ThemeColorRole.bottomBackgroundNight
                : ThemeColorRole.bottomBackground:
            preset.bottomBackground,
      });

  ThemeDocument currentDocument() {
    final colors = _ref.read(themeColorsProvider);
    final theme = _ref.read(themeNotifierProvider);
    return ThemeDocument(
      paletteId: theme.paletteId,
      themeMode: theme.themeMode.name,
      day: ThemeDocumentColors(
        primary: colors.primary,
        accent: colors.accent,
        background: colors.background,
        bottomBackground: colors.bottomBackground,
      ),
      night: ThemeDocumentColors(
        primary: colors.primaryNight,
        accent: colors.accentNight,
        background: colors.backgroundNight,
        bottomBackground: colors.bottomBackgroundNight,
      ),
    );
  }

  Future<bool> exportTheme() =>
      _ref.read(themeFileServiceProvider).exportTheme(currentDocument());

  Future<ThemeDocument?> readThemeFile() =>
      _ref.read(themeFileServiceProvider).importTheme();

  Future<void> applyDocument(ThemeDocument document) async {
    final colors = _ref.read(themeColorsProvider.notifier);
    final theme = _ref.read(themeNotifierProvider.notifier);
    await colors.applyColors({
      ThemeColorRole.primary: document.day.primary,
      ThemeColorRole.accent: document.day.accent,
      ThemeColorRole.background: document.day.background,
      ThemeColorRole.bottomBackground: document.day.bottomBackground,
      ThemeColorRole.primaryNight: document.night.primary,
      ThemeColorRole.accentNight: document.night.accent,
      ThemeColorRole.backgroundNight: document.night.background,
      ThemeColorRole.bottomBackgroundNight: document.night.bottomBackground,
    });
    final mode = switch (document.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
    if (mode != null || document.paletteId != null) {
      await theme.applyAppearance(
        themeMode: mode,
        paletteId: document.paletteId,
      );
    }
  }
}
