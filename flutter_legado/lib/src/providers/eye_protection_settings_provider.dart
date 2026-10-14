import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_eye_protection_settings_repository.dart';
import '../domain/contracts/eye_protection_settings_repository.dart';
import 'app_settings_provider.dart';

final eyeProtectionSettingsRepositoryProvider =
    Provider<EyeProtectionSettingsRepository>(
      (ref) => AppEyeProtectionSettingsRepository(
        ref.watch(appSettingsServiceProvider),
      ),
    );
