import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_read_aloud_settings_repository.dart';
import '../../domain/contracts/read_aloud_settings_repository.dart';
import '../../providers/app_settings_provider.dart';

final readAloudSettingsRepositoryProvider =
    Provider<ReadAloudSettingsRepository>(
      (ref) =>
          AppReadAloudSettingsRepository(ref.watch(appSettingsServiceProvider)),
    );
