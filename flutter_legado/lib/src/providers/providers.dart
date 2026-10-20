export '../app/bootstrap/application_dependencies.dart'
    show readingConfigSyncProvider, appRuntimeProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings_service.dart';

final settingsProvider = Provider<SettingsService>((ref) => SettingsService());
