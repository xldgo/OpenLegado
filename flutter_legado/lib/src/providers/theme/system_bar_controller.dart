import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/settings_write_queue.dart';
import '../../services/system_bar_service.dart';

typedef ApplicationSystemBars = ({Color appBarColor, Color navigationBarColor});

typedef ReaderSystemBars = ({bool statusBarVisible, bool navigationBarVisible});

/// 应用保留最新样式，阅读器只在页面可见期间接管系统栏显隐。
class SystemBarController {
  SystemBarController({
    required this.applyApplication,
    required this.applyReader,
  });

  final Future<void> Function(ApplicationSystemBars) applyApplication;
  final Future<void> Function(ReaderSystemBars) applyReader;
  final _operations = SettingsWriteQueue();
  final _readers = <Object, ReaderSystemBars>{};
  ApplicationSystemBars? _application;
  int _revision = 0;
  bool _disposed = false;

  void updateApplication(ApplicationSystemBars configuration) {
    if (_disposed || _application == configuration) return;
    _application = configuration;
    if (_readers.isEmpty) reapply();
  }

  void updateReader(Object owner, ReaderSystemBars configuration) {
    if (_disposed) return;
    if (_readers.isNotEmpty &&
        identical(_readers.keys.last, owner) &&
        _readers[owner] == configuration) {
      return;
    }
    _readers.remove(owner);
    _readers[owner] = configuration;
    reapply();
  }

  void releaseReader(Object owner) {
    if (_disposed || !_readers.containsKey(owner)) return;
    final wasActive = identical(_readers.keys.last, owner);
    _readers.remove(owner);
    if (wasActive) reapply();
  }

  /// 前台恢复时重新下发当前归属；已有异步请求按顺序完成，过期排队项跳过。
  void reapply() {
    if (_disposed) return;
    final revision = ++_revision;
    unawaited(
      _operations
          .run(() async {
            if (_disposed || revision != _revision) return;
            if (_readers.isNotEmpty) {
              await applyReader(_readers.values.last);
            } else if (_application case final application?) {
              await applyApplication(application);
            }
          })
          .catchError((Object error) {
            if (!_disposed) debugPrint('系统栏样式应用失败: $error');
          }),
    );
  }

  void dispose() {
    _disposed = true;
    _revision++;
    _readers.clear();
  }
}

final systemBarControllerProvider = Provider<SystemBarController>((ref) {
  final controller = SystemBarController(
    applyApplication: (configuration) => SystemBarService.apply(
      appBarColor: configuration.appBarColor,
      navigationBarColor: configuration.navigationBarColor,
    ),
    applyReader: (configuration) => SystemBarService.applyReader(
      statusBarVisible: configuration.statusBarVisible,
      navigationBarVisible: configuration.navigationBarVisible,
    ),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
