import 'dart:async';

import '../../../platform/display/screen_awake.dart';

/// 阅读交互重新计时，到期只解除屏幕防休眠，不强制熄屏。— Codex + UI
final class ReaderKeepAwakeController {
  ReaderKeepAwakeController(this._screen);

  final ScreenAwake _screen;
  final _owner = Object();
  Timer? _timer;
  int _seconds = 0;
  bool _visible = false;
  bool _disposed = false;

  void configure(int seconds) {
    if (_disposed || _seconds == seconds) return;
    _seconds = seconds;
    if (_visible) _restart();
  }

  void setVisible(bool visible) {
    if (_disposed || _visible == visible) return;
    _visible = visible;
    _restart();
  }

  void onInteraction() {
    if (!_disposed && _visible) _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    final held = _visible && _seconds != 0;
    unawaited(_screen.setHeld(_owner, held));
    if (held && _seconds > 0) {
      _timer = Timer(Duration(seconds: _seconds), () {
        _timer = null;
        unawaited(_screen.setHeld(_owner, false));
      });
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_screen.setHeld(_owner, false));
  }
}
