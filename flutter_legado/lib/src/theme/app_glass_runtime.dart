import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// 一次性预热玻璃资源，失败只关闭玻璃能力，不阻止应用启动。— Codex + UI
final class AppGlassRuntime {
  AppGlassRuntime({Future<void> Function()? initialize})
    : _initializer = initialize ?? _prewarm;

  final Future<void> Function() _initializer;
  Future<void>? _initialization;
  bool _available = false;
  Object? _error;

  bool get available => _available;
  Object? get error => _error;

  Future<void> initialize() => _initialization ??= _prepare();

  Future<void> _prepare() async {
    try {
      await _initializer();
      _available = true;
    } catch (error) {
      _error = error;
      debugPrint('[玻璃材质] 资源预热失败，保留普通材质：$error');
    }
  }

  // 使用项目自己的性能取证，避免库的帧预算告警写入应用崩溃记录。
  static Future<void> _prewarm() =>
      LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
}
