import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_welcome_settings_repository.dart';
import '../domain/contracts/welcome_settings_repository.dart';
import 'app_settings_provider.dart';
import '../domain/models/welcome_settings.dart';

final welcomeSettingsRepositoryProvider = Provider<WelcomeSettingsRepository>(
  (ref) => AppWelcomeSettingsRepository(ref.watch(appSettingsServiceProvider)),
);

final welcomeSettingsProvider = StreamProvider<WelcomeSettings>((ref) async* {
  final repository = ref.watch(welcomeSettingsRepositoryProvider);
  await repository.load();
  yield* repository.watch();
});
