import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_read_record_settings_repository.dart';
import '../domain/contracts/read_record_settings_repository.dart';
import 'app_settings_provider.dart';

final readRecordSettingsRepositoryProvider =
    Provider<ReadRecordSettingsRepository>(
      (ref) => AppReadRecordSettingsRepository(
        ref.watch(appSettingsServiceProvider),
      ),
    );
