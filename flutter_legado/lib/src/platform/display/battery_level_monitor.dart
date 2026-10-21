import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/widgets.dart';

/// 阅读期间共享插件电量；刷新只影响提示，不参与正文排版。— Codex + UI
final class BatteryLevelMonitor extends ValueNotifier<int?>
    with WidgetsBindingObserver {
  BatteryLevelMonitor() : super(null) {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _battery.onBatteryStateChanged.listen(
      (_) => unawaited(refresh()),
      onError: (Object error) {
        debugPrint('读取电池状态失败：$error');
      },
    );
    if (WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _startRefreshing();
    }
  }

  final _battery = Battery();
  StreamSubscription<BatteryState>? _subscription;
  Timer? _timer;
  bool _disposed = false;
  bool _reading = false;

  void _startRefreshing() {
    _timer?.cancel();
    unawaited(refresh());
    // 插件事件只表示充放电状态，不保证每次百分比变化都会通知。
    // 仅阅读器在前台时每分钟补读，后台及离开阅读器后不轮询。
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_disposed || _reading) return;
    _reading = true;
    int? level;
    try {
      final raw = await _battery.batteryLevel;
      level = raw >= 0 && raw <= 100 ? raw : null;
    } catch (error) {
      debugPrint('读取系统电量失败：$error');
    } finally {
      _reading = false;
    }
    if (!_disposed) value = level;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRefreshing();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
