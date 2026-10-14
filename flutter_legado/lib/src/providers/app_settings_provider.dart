import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/app_settings_service.dart';
import '../app/bootstrap/app_settings_factory.dart';
import 'providers.dart' show bookApiProvider;

/// 同一根只装配一个设置协调服务；根替换后消费者跟随替换。— Codex + UI
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  final api = ref.watch(bookApiProvider);
  final service = createAppSettingsService(
    readConfig: api.getConfig,
    writeConfig: api.setConfig,
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
