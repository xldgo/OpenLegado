import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 汇总页面持有者并串行调用平台，避免旧页面的释放覆盖新页面。— Codex + UI
final class ScreenAwake {
  ScreenAwake({Future<void> Function(bool)? toggle})
    : _toggle = toggle ?? ((enabled) => WakelockPlus.toggle(enable: enabled));

  final Future<void> Function(bool) _toggle;
  final _owners = <Object>{};
  Future<void> _pending = Future.value();
  bool? _applied;

  Future<void> setHeld(Object owner, bool held) {
    if (held) {
      _owners.add(owner);
    } else {
      _owners.remove(owner);
    }
    _pending = _pending.then((_) async {
      // 等待期间持有者可能变化，只提交最新意图。
      final enabled = _owners.isNotEmpty;
      if (_applied == enabled) return;
      try {
        await _toggle(enabled);
        _applied = enabled;
      } catch (error) {
        // 不记录成功状态，下次交互或生命周期变化可再次尝试。
        debugPrint('更新阅读保持亮屏失败：$error');
      }
    });
    return _pending;
  }
}
