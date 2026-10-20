import 'dart:async';

import '../../domain/models/reader_theme_mode.dart';

/// 正文与书源快照共享的会话覆盖；不写入偏好或备份。— Codex + UI
final class ReaderThemeSession {
  ReaderThemeMode _mode = ReaderThemeMode.followApp;
  final _changes = StreamController<ReaderThemeMode>.broadcast();

  ReaderThemeMode get mode => _mode;

  bool? get isNightOverride => switch (_mode) {
    ReaderThemeMode.followApp => null,
    ReaderThemeMode.day => false,
    ReaderThemeMode.night => true,
  };

  Stream<ReaderThemeMode> watch() => Stream.multi((listener) {
    final subscription = _changes.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.add(_mode);
    listener.onCancel = subscription.cancel;
  });

  void setMode(ReaderThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _changes.add(mode);
  }

  void reset() => setMode(ReaderThemeMode.followApp);

  Future<void> dispose() => _changes.close();
}
