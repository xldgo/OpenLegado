import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_system_bar_settings_repository.dart';
import '../../domain/contracts/system_bar_settings_repository.dart';
import '../app_settings_provider.dart';

final systemBarSettingsRepositoryProvider =
    Provider<SystemBarSettingsRepository>(
      (ref) =>
          AppSystemBarSettingsRepository(ref.watch(appSettingsServiceProvider)),
    );
