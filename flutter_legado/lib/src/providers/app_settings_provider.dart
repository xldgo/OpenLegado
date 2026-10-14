import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/app_settings_service.dart';
import '../data/settings/config_settings_storage.dart';
import '../data/settings/shared_preferences_settings_storage.dart';
import '../domain/models/app_settings_snapshot.dart';
import 'providers.dart' show bookApiProvider;

/// 同一根只装配一个设置协调服务；根替换后消费者跟随替换。— Codex + UI
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  final api = ref.watch(bookApiProvider);
  final service = AppSettingsService(
    storages: {
      SettingsStorageKind.rustConfig: ConfigSettingsStorage(
        read: api.getConfig,
        write: api.setConfig,
      ),
      SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
    },
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
