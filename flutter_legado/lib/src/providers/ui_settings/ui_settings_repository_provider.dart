import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_ui_settings_repository.dart';
import '../../domain/contracts/ui_settings_repository.dart';
import '../app_settings_provider.dart';

final uiSettingsRepositoryProvider = Provider<UiSettingsRepository>(
  (ref) => AppUiSettingsRepository(ref.watch(appSettingsServiceProvider)),
);
