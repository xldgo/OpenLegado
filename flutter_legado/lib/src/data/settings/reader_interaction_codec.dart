import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/reader_auto_page_turn_settings.dart';
import '../../domain/models/reader_interaction_settings.dart';

/// 自动翻页和操作偏好的规范键与类型映射，不执行IO。— Codex + UI
final class ReaderInteractionCodec {
  const ReaderInteractionCodec();

  static const _keys = [
    'auto_page_turn_enabled',
    'auto_page_turn_interval_seconds',
    'auto_page_turn_forward',
    'tap_actions',
    'select_text',
    'no_anim_scroll_page',
    'volume_key_page',
    'volume_key_page_on_play',
    'mouse_wheel_page',
    'page_touch_slop',
    'page_touch_click',
    'progress_bar_behavior',
  ];

  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: 'reader_$key');

  Set<SettingsAddress> get addresses => {
    for (final key in _keys) _address(key),
  };

  bool _bool(AppSettingsSnapshot snapshot, String key, bool fallback) =>
      snapshot[_address(key)] is bool
      ? snapshot[_address(key)] as bool
      : fallback;

  int _int(AppSettingsSnapshot snapshot, String key, int max) =>
      (snapshot[_address(key)] is int ? snapshot[_address(key)] as int : 0)
          .clamp(0, max);

  List<TapAction> _actions(AppSettingsSnapshot snapshot) {
    final stored = snapshot[_address('tap_actions')];
    if (stored is! SettingsStringList || stored.values.length != 9) {
      return ReaderInteractionSettings.defaultTapActions;
    }
    final value = stored.values;
    final actions = {
      for (final action in TapAction.values) action.name: action,
    };
    if (value.any((name) => !actions.containsKey(name))) {
      return ReaderInteractionSettings.defaultTapActions;
    }
    return [for (final name in value) actions[name]!];
  }

  ReaderAutoPageTurnSettings decodeAutoPageTurn(AppSettingsSnapshot snapshot) =>
      ReaderAutoPageTurnSettings(
        enabled: _bool(snapshot, 'auto_page_turn_enabled', false),
        intervalSeconds:
            (snapshot[_address('auto_page_turn_interval_seconds')] is double
                    ? snapshot[_address('auto_page_turn_interval_seconds')]
                          as double
                    : 10.0)
                .clamp(3.0, 120.0),
        forward: _bool(snapshot, 'auto_page_turn_forward', true),
      );

  ReaderInteractionSettings decodeInteraction(AppSettingsSnapshot snapshot) =>
      ReaderInteractionSettings(
        tapActions: _actions(snapshot),
        selectText: _bool(snapshot, 'select_text', true),
        noAnimScrollPage: _bool(snapshot, 'no_anim_scroll_page', false),
        volumeKeyPage: _bool(snapshot, 'volume_key_page', true),
        volumeKeyPageOnPlay: _bool(snapshot, 'volume_key_page_on_play', false),
        mouseWheelPage: _bool(snapshot, 'mouse_wheel_page', true),
        pageTouchSlop: _int(snapshot, 'page_touch_slop', 9999),
        pageTouchClick: _int(snapshot, 'page_touch_click', 399),
        progressBarBehavior:
            snapshot[_address('progress_bar_behavior')] == 'chapter'
            ? 'chapter'
            : 'page',
      );

  Map<SettingsAddress, Object?> autoPageTurnPatch({
    bool? enabled,
    double? intervalSeconds,
    bool? forward,
  }) => {
    _address('auto_page_turn_enabled'): ?enabled,
    _address('auto_page_turn_interval_seconds'): ?intervalSeconds?.clamp(
      3.0,
      120.0,
    ),
    _address('auto_page_turn_forward'): ?forward,
  };

  SettingsStringList _encodeActions(List<TapAction> actions) =>
      SettingsStringList(
        ReaderInteractionSettings(tapActions: actions).tapActions
            .map((action) => action.name),
      );

  Map<SettingsAddress, Object?> interactionPatch({
    List<TapAction>? tapActions,
    bool? selectText,
    bool? noAnimScrollPage,
    bool? volumeKeyPage,
    bool? volumeKeyPageOnPlay,
    bool? mouseWheelPage,
    int? pageTouchSlop,
    int? pageTouchClick,
    String? progressBarBehavior,
  }) => {
    _address('tap_actions'): ?(tapActions == null
        ? null
        : _encodeActions(tapActions)),
    _address('select_text'): ?selectText,
    _address('no_anim_scroll_page'): ?noAnimScrollPage,
    _address('volume_key_page'): ?volumeKeyPage,
    _address('volume_key_page_on_play'): ?volumeKeyPageOnPlay,
    _address('mouse_wheel_page'): ?mouseWheelPage,
    _address('page_touch_slop'): ?pageTouchSlop?.clamp(0, 9999),
    _address('page_touch_click'): ?pageTouchClick?.clamp(0, 399),
    if (progressBarBehavior != null)
      _address('progress_bar_behavior'): progressBarBehavior == 'chapter'
          ? 'chapter'
          : 'page',
  };
}
