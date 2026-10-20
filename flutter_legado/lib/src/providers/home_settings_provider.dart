import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_home_settings_repository.dart';
import '../domain/contracts/home_settings_repository.dart';
import 'app_settings_provider.dart';

/// 复用根设置服务，允许独立注入主界面仓储。— Codex + UI
final homeSettingsRepositoryProvider = Provider<HomeSettingsRepository>(
  (ref) => AppHomeSettingsRepository(ref.watch(appSettingsServiceProvider)),
);
