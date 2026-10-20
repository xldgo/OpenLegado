import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

/// 胶囊只保存界面偏好，播放与定时继续由 AudioNotifier 管理。
class ReadAloudCapsuleState {
  const ReadAloudCapsuleState({
    this.x = 1,
    this.y = 0.85,
    this.autoCollapse = true,
    this.classicExpanded = false,
  });

  final double x;
  final double y;
  final bool autoCollapse;
  final bool classicExpanded;

  ReadAloudCapsuleState copyWith({
    double? x,
    double? y,
    bool? autoCollapse,
    bool? classicExpanded,
  }) => ReadAloudCapsuleState(
    x: x ?? this.x,
    y: y ?? this.y,
    autoCollapse: autoCollapse ?? this.autoCollapse,
    classicExpanded: classicExpanded ?? this.classicExpanded,
  );
}

class ReadAloudCapsuleController extends Notifier<ReadAloudCapsuleState> {
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  bool _positionTouched = false;
  bool _autoCollapseTouched = false;

  @override
  ReadAloudCapsuleState build() => const ReadAloudCapsuleState();

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = state.copyWith(
      x: _positionTouched
          ? state.x
          : _coordinate(preferences.getDouble('read_aloud_capsule_x'), 1),
      y: _positionTouched
          ? state.y
          : _coordinate(preferences.getDouble('read_aloud_capsule_y'), 0.85),
      autoCollapse: _autoCollapseTouched
          ? state.autoCollapse
          : preferences.getBool('read_aloud_capsule_auto_collapse') ?? true,
    );
  }

  double _coordinate(double? value, double fallback) =>
      value != null && value.isFinite ? value.clamp(0, 1) : fallback;

  Future<void> _save(Future<void> Function(SharedPreferences) action) {
    final operation = _writes.then((_) async {
      await action(await SharedPreferences.getInstance());
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> setPosition(double x, double y) {
    _positionTouched = true;
    final position = state.copyWith(
      x: _coordinate(x, state.x),
      y: _coordinate(y, state.y),
    );
    state = position;
    return _save((preferences) async {
      if (!await preferences.setDouble('read_aloud_capsule_x', position.x) ||
          !await preferences.setDouble('read_aloud_capsule_y', position.y)) {
        throw StateError('胶囊位置保存失败');
      }
    });
  }

  Future<void> setAutoCollapse(bool value) {
    _autoCollapseTouched = true;
    state = state.copyWith(autoCollapse: value);
    return _save((preferences) async {
      if (!await preferences.setBool(
        'read_aloud_capsule_auto_collapse',
        value,
      )) {
        throw StateError('胶囊偏好保存失败');
      }
    });
  }

  void showClassic(bool value) {
    if (state.classicExpanded != value) {
      state = state.copyWith(classicExpanded: value);
    }
  }
}

final readAloudCapsuleProvider =
    NotifierProvider<ReadAloudCapsuleController, ReadAloudCapsuleState>(
      ReadAloudCapsuleController.new,
    );
