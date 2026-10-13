import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../constants/pref_keys.dart';
import '../../data/repositories/preferences_theme_preset_repository.dart';
import '../../domain/contracts/theme_preset_repository.dart';
import '../../models/theme_document.dart';
import '../../models/theme_preset.dart';
import '../../platform/files/theme_file_service.dart';
import '../../providers/providers.dart';
import '../../providers/theme/theme_colors_notifier.dart';
import '../../providers/theme/theme_notifier.dart';

final themePresetRepositoryProvider = Provider<ThemePresetRepository>(
  (ref) => PreferencesThemePresetRepository(ref.watch(settingsProvider)),
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
        preset.isNight ? PrefKeys.cNPrimary : PrefKeys.cPrimary: preset.primary,
        preset.isNight ? PrefKeys.cNAccent : PrefKeys.cAccent: preset.accent,
        preset.isNight ? PrefKeys.cNBackground : PrefKeys.cBackground:
            preset.background,
        preset.isNight ? PrefKeys.cNBBackground : PrefKeys.cBBackground:
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
      PrefKeys.cPrimary: document.day.primary,
      PrefKeys.cAccent: document.day.accent,
      PrefKeys.cBackground: document.day.background,
      PrefKeys.cBBackground: document.day.bottomBackground,
      PrefKeys.cNPrimary: document.night.primary,
      PrefKeys.cNAccent: document.night.accent,
      PrefKeys.cNBackground: document.night.background,
      PrefKeys.cNBBackground: document.night.bottomBackground,
    });
    if (document.paletteId case final String paletteId) {
      await theme.setPaletteId(paletteId);
    }
    final mode = switch (document.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
    if (mode != null) await theme.setThemeMode(mode);
  }
}
