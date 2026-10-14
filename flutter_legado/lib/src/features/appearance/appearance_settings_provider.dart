import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_appearance_settings_repository.dart';
import '../../domain/contracts/appearance_settings_repository.dart';
import '../../domain/models/appearance_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../data/bridge/runtime_configuration.dart';

final appearanceSettingsRepositoryProvider =
    Provider<AppearanceSettingsRepository>(
      (ref) => AppAppearanceSettingsRepository(
        ref.watch(appSettingsServiceProvider),
      ),
    );

final appearanceSettingsProvider = StreamProvider<AppearanceSettings>((
  ref,
) async* {
  final repository = ref.watch(appearanceSettingsRepositoryProvider);
  await repository.load();
  yield* repository.watch();
});

/// 正式启动注入已初始化的能力；独立 UI 与 Mock 不调用原生桥。— Codex + UI
final themeConfigSyncProvider = Provider<ThemeConfigSync>(
  (ref) => const NoopThemeConfigSync(),
);
