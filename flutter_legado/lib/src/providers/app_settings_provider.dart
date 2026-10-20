import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/app_settings_service.dart';
import '../app/bootstrap/app_settings_factory.dart';
import 'config_provider.dart';

/// 同一根只装配一个设置协调服务；根替换后消费者跟随替换。— Codex + UI
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  final config = ref.watch(configRepositoryProvider);
  final service = createAppSettingsService(configRepository: () => config);
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
