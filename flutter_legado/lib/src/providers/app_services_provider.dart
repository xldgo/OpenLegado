import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/app_services_controller.dart';
import '../services/auto_task_scheduler.dart';
import 'config_settings_provider.dart';
import 'domain_config_provider.dart';
import 'general_settings_provider.dart';
import 'local_server_provider.dart';
import 'web_keep_alive_provider.dart';

/// 页面只订阅；启动和前台恢复复用同一个应用级控制器。— Codex + UI
final appServicesControllerProvider = Provider<AppServicesController>((ref) {
  final keepAlive = ref.watch(webKeepAliveServiceProvider);
  final controller = AppServicesController(
    server: ref.watch(localServerServiceProvider),
    settings: ref.watch(serviceSettingsRepositoryProvider),
    general: ref.watch(generalSettingsRepositoryProvider),
    access: ref.watch(serverAccessRepositoryProvider),
    startKeepAlive: keepAlive.start,
    stopKeepAlive: keepAlive.stop,
    refreshAuto: AutoTaskScheduler.instance.refresh,
    cancelAuto: AutoTaskScheduler.instance.cancelAll,
    log: (message, error) => debugPrint('$message：$error'),
  );
  ref.onDispose(() {
    controller.dispose();
    unawaited(
      Future.sync(keepAlive.stop).then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          debugPrint('释放Web保活失败：$error');
        },
      ),
    );
  });
  return controller;
});
