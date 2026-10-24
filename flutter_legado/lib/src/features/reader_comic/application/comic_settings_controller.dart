import 'package:flutter/foundation.dart';

import '../../../domain/contracts/manga_settings_repository.dart';
import '../../../domain/models/manga_settings.dart';
import '../../../models/models.dart';
import '../../../models/manga_auto_read.dart';
import '../../../models/manga_click_actions.dart';
import '../../../models/manga_page_scale_type.dart';
import '../../../models/manga_scroll_mode.dart';

/// 页面只持有这一份设置快照，书级配置取自当前会话。— Codex + UI
class ComicSettingsController extends ChangeNotifier {
  ComicSettingsController(this._repository);

  final MangaSettingsRepository _repository;
  MangaSettings _current = MangaSettings(
    colorFilter: MangaColorFilterConfig(),
    footer: MangaFooterConfig(),
    clickActions: MangaClickActions.defaultActions,
  );
  MangaSettings get current => _current;
  bool _disposed = false;

  static int? bookScrollMode(ReadConfig? config) {
    final value = config?.mangaScrollMode;
    return MangaScrollModes.valid.contains(value) ? value : null;
  }

  static int? bookSidePadding(ReadConfig? config) =>
      config?.webtoonSidePaddingDp?.clamp(0, 45);

  int scrollMode(ReadConfig? config) =>
      bookScrollMode(config) ?? current.scrollMode;
  int sidePadding(ReadConfig? config) =>
      bookSidePadding(config) ?? current.sidePadding;

  Future<bool> load() async {
    try {
      final settings = await _repository.load();
      if (_disposed) return false;
      _current = settings;
      notifyListeners();
      return true;
    } catch (_) {
      // 沿用读取失败保留当前显示的策略。
      return false;
    }
  }

  Future<void> _update(MangaSettings Function(MangaSettings) transform) async {
    if (_disposed) return;
    _current = transform(_current);
    notifyListeners();
    try {
      // 逐字段变换存储最新值，不把页面整份快照写回。
      await _repository.update(transform);
    } catch (_) {
      // 沿用保存失败保留本次内存显示的策略，不阻断阅读。
    }
  }

  Future<void> setScrollMode(int value) => _update(
    (s) => s.copyWith(
      scrollMode: MangaScrollModes.valid.contains(value)
          ? value
          : MangaScrollModes.defaultValue,
    ),
  );
  Future<void> setSidePadding(int value) =>
      _update((s) => s.copyWith(sidePadding: value.clamp(0, 45)));
  Future<void> setAutoReadSpeed(int value) =>
      _update((s) => s.copyWith(autoReadSpeed: MangaAutoRead.parse('$value')));
  Future<void> setPageScaleType(int value) => _update(
    (s) => s.copyWith(pageScaleType: MangaPageScaleType.parse('$value')),
  );
  Future<void> setDoublePageMode(int value) => _update(
    (s) => s.copyWith(doublePageMode: MangaDoublePageMode.parse('$value')),
  );

  Future<void> setWidePageMode(int value) => _update(
    (s) => s.copyWith(widePageMode: MangaWidePageMode.parse('$value')),
  );
  Future<void> setPreloadImages(bool enabled) async {
    await _repository.update((s) => s.copyWith(preloadImages: enabled));
    if (_disposed) return;
    _current = _current.copyWith(preloadImages: enabled);
    notifyListeners();
  }

  Future<void> setAutoOfflineCache(bool enabled) async {
    await _repository.update((s) => s.copyWith(autoOfflineCache: enabled));
    if (_disposed) return;
    _current = _current.copyWith(autoOfflineCache: enabled);
    notifyListeners();
  }

  Future<void> setThreshold(int value) =>
      _update((s) => s.copyWith(eInkThreshold: value.clamp(0, 255)));
  Future<void> setToggle(MangaToggle option, bool enabled) =>
      _update((s) => s.withToggle(option, enabled));
  Future<void> setEInk(bool enabled) => _update(
    (s) => s.copyWith(
      enableEInk: enabled,
      enableGray: enabled ? false : s.enableGray,
    ),
  );
  Future<void> setGray(bool enabled) => _update(
    (s) => s.copyWith(
      enableGray: enabled,
      enableEInk: enabled ? false : s.enableEInk,
    ),
  );
  Future<void> setBackground(int value) async {
    if (value < 0 || value > 0xFFFFFFFF || value == current.backgroundColor) {
      return;
    }
    await _update((s) => s.copyWith(backgroundColor: value));
  }

  Future<void> setColorFilter(MangaColorFilterConfig value) {
    final copy = MangaColorFilterConfig.fromJson(value.toJson());
    return _update((s) => s.copyWith(colorFilter: copy));
  }

  Future<void> setFooter(MangaFooterConfig value) {
    final copy = MangaFooterConfig.fromJson(value.toJson());
    return _update((s) => s.copyWith(footer: copy));
  }

  Future<void> cycleClickAction(int index) async {
    if (index < 0 || index >= current.clickActions.length) return;
    final next = MangaClickActions.cycleNext(current.clickActions[index]);
    await _update(
      (s) => s.copyWith(
        clickActions: List.unmodifiable(
          List<int>.of(s.clickActions)..[index] = next,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
