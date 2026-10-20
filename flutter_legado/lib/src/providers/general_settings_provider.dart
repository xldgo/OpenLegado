import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_general_settings_repository.dart';
import '../domain/contracts/general_settings_repository.dart';
import '../domain/models/general_settings.dart';
import 'app_settings_provider.dart';

final generalSettingsRepositoryProvider = Provider<GeneralSettingsRepository>(
  (ref) => AppGeneralSettingsRepository(ref.watch(appSettingsServiceProvider)),
);

final generalSettingsProvider = StreamProvider<GeneralSettings>((ref) async* {
  final repository = ref.watch(generalSettingsRepositoryProvider);
  await repository.load();
  yield* repository.watch();
});
