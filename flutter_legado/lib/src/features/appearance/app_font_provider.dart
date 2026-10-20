import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/app_font_service.dart';
import '../../platform/app_font_picker.dart';
import '../../providers/font_catalog_provider.dart';
import 'appearance_settings_provider.dart';

final appFontPickerProvider = Provider<AppFontPicker>((ref) => AppFontPicker());
final appFontServiceProvider = Provider<AppFontService>(
  (ref) => AppFontService(
    settings: ref.watch(appearanceSettingsRepositoryProvider),
    catalog: ref.watch(fontCatalogServiceProvider),
    picker: ref.watch(appFontPickerProvider),
  ),
);

/// 冷启动和恢复后先注册已选字体；缺失或损坏时由调用方回退系统默认。
final appFontFamilyProvider = FutureProvider<String?>((ref) async {
  final family = ref.watch(
    appearanceSettingsProvider.select(
      (settings) => settings.value?.fontFamily ?? '',
    ),
  );
  if (family.isEmpty) return null;
  ref.watch(readerFontsProvider);
  return ref.watch(fontCatalogServiceProvider).loadFamily(family);
});

final availableAppFontsProvider = FutureProvider((ref) {
  ref.watch(readerFontsProvider);
  return ref.watch(fontCatalogServiceProvider).loadAvailable();
});
