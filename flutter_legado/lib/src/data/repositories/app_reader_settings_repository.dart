import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contracts/reader_settings_repository.dart';
import '../../domain/models/reader_settings.dart';
import '../../domain/models/reader_text_layout_settings.dart';
import '../../domain/models/reader_page_layout_settings.dart';
import '../settings/reader_page_layout_codec.dart';
import '../../domain/models/page_turn_mode.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../services/app_settings_service.dart';
import '../../models/reader_advanced_config.dart';
import '../../services/reader_settings_migration.dart';
import '../../services/settings_write_queue.dart';

/// 基础阅读偏好使用共享服务，高级配置沿用原格式和串行读改写。— Codex + UI
class AppReaderSettingsRepository implements ReaderSettingsRepository {
  AppReaderSettingsRepository(
    this._service, {
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static const _prefix = 'reader_adv_';
  static const _pageLayout = ReaderPageLayoutCodec();
  final AppSettingsService _service;
  bool _loaded = false;
  Future<ReaderSettings>? _loading;
  static const _mode = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_flip_mode_name',
  );
  static const _legacyIndex = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_flip_mode',
  );
  static const _fontSize = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_font_size',
  );
  static const _lineHeight = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_line_height',
  );
  static const _fontFamily = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_font_family',
  );
  static const _titleFont = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_title_font_family',
  );
  static const _paragraphSpacing = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_paragraph_spacing',
  );
  static const _letterSpacing = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_letter_spacing',
  );
  static const _paragraphIndent = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_paragraph_indent',
  );
  static const _textFullJustify = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_text_full_justify',
  );
  static const _textBold = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_text_bold',
  );
  static const _italic = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_italic',
  );
  static const _useZhLayout = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_use_zh_layout',
  );
  static const _hangingPunctuation = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_hanging_punctuation',
  );
  static const _addresses = {
    _mode,
    _legacyIndex,
    _fontSize,
    _lineHeight,
    _fontFamily,
    _titleFont,
    _tocLoadWordCount,
    _chapterInSystemBrowser,
    _paragraphSpacing,
    _letterSpacing,
    _paragraphIndent,
    _textFullJustify,
    _textBold,
    _italic,
    _useZhLayout,
    _hangingPunctuation,
  };
  static const _tocLoadWordCount = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_toc_load_word_count',
  );
  static const _chapterInSystemBrowser = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_chapter_in_system_browser',
  );
  final Future<SharedPreferences> Function() _preferences;
  final SettingsWriteQueue _operations = SettingsWriteQueue();

  ReaderSettings _decode(AppSettingsSnapshot snapshot) => ReaderSettings(
    pageTurnMode: PageTurnMode.fromStorage(
      snapshot[_mode] is String ? snapshot[_mode] as String : null,
      snapshot[_legacyIndex] is int ? snapshot[_legacyIndex] as int : null,
    ),
    fontSize: snapshot[_fontSize] is double
        ? snapshot[_fontSize] as double
        : 20.0,
    lineHeight: snapshot[_lineHeight] is double
        ? snapshot[_lineHeight] as double
        : 1.7,
    fontFamily: snapshot[_fontFamily] is String
        ? snapshot[_fontFamily] as String
        : null,
    titleFontFamily: snapshot[_titleFont] is String
        ? snapshot[_titleFont] as String
        : '',
    tocLoadWordCount: snapshot[_tocLoadWordCount] is bool
        ? snapshot[_tocLoadWordCount] as bool
        : true,
    chapterInSystemBrowser: snapshot[_chapterInSystemBrowser] is bool
        ? snapshot[_chapterInSystemBrowser] as bool
        : false,
    pageLayout: _pageLayout.decode(snapshot),
    textLayout: ReaderTextLayoutSettings(
      paragraphSpacing:
          (snapshot[_paragraphSpacing] is double
                  ? snapshot[_paragraphSpacing] as double
                  : 2)
              .clamp(0, 48)
              .toDouble(),
      letterSpacing:
          (snapshot[_letterSpacing] is double
                  ? snapshot[_letterSpacing] as double
                  : 0)
              .clamp(-0.5, 1)
              .toDouble(),
      paragraphIndent:
          (snapshot[_paragraphIndent] is int
                  ? snapshot[_paragraphIndent] as int
                  : 2)
              .clamp(0, 3),
      textFullJustify: (snapshot[_textFullJustify] is bool
          ? snapshot[_textFullJustify] as bool
          : true),
      textBold: (snapshot[_textBold] is int ? snapshot[_textBold] as int : 0)
          .clamp(0, 2),
      italic: (snapshot[_italic] is bool ? snapshot[_italic] as bool : false),
      useZhLayout: (snapshot[_useZhLayout] is bool
          ? snapshot[_useZhLayout] as bool
          : false),
      hangingPunctuation: (snapshot[_hangingPunctuation] is bool
          ? snapshot[_hangingPunctuation] as bool
          : false),
    ),
  );

  @override
  ReaderSettings get current => _decode(_service.current);
  @override
  Stream<ReaderSettings> watch() => _service.watch().map(_decode).distinct();
  @override
  Future<ReaderSettings> load() {
    if (_loaded) return Future.value(current);
    return _loading ??= _service
        .load({..._addresses, ..._pageLayout.addresses})
        .then((_) {
          _loaded = true;
          return current;
        })
        .whenComplete(() => _loading = null);
  }

  @override
  Future<void> reload() async {
    await _service.reload({..._addresses, ..._pageLayout.addresses});
    _loaded = true;
  }

  @override
  Future<void> update({
    PageTurnMode? pageTurnMode,
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    String? titleFontFamily,
    bool? tocLoadWordCount,
    bool? chapterInSystemBrowser,
  }) => _service.update({
    _mode: ?pageTurnMode?.name,
    _fontSize: ?fontSize,
    _lineHeight: ?lineHeight,
    if (fontFamily != null) _fontFamily: fontFamily.isEmpty ? null : fontFamily,
    _titleFont: ?titleFontFamily,
    _tocLoadWordCount: ?tocLoadWordCount,
    _chapterInSystemBrowser: ?chapterInSystemBrowser,
  });

  @override
  Future<void> updateTextLayout({
    double? paragraphSpacing,
    double? letterSpacing,
    int? paragraphIndent,
    bool? textFullJustify,
    int? textBold,
    bool? italic,
    bool? useZhLayout,
    bool? hangingPunctuation,
  }) => _service.update({
    _paragraphSpacing: ?paragraphSpacing?.clamp(0.0, 48.0),
    _letterSpacing: ?letterSpacing?.clamp(-0.5, 1.0),
    _paragraphIndent: ?paragraphIndent?.clamp(0, 3),
    _textFullJustify: ?textFullJustify,
    _textBold: ?textBold?.clamp(0, 2),
    _italic: ?italic,
    _useZhLayout: ?useZhLayout,
    _hangingPunctuation: ?hangingPunctuation,
  });

  @override
  Future<void> updatePageLayout({
    double? top,
    double? bottom,
    double? left,
    double? right,
    int? doubleHorizontalPage,
  }) => _service.update(
    _pageLayout.pagePatch(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      doubleHorizontalPage: doubleHorizontalPage,
    ),
  );

  @override
  Future<void> updatePageEdge(
    ReaderPageEdge edge, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    int? mode,
    bool? showLine,
    int? leftTip,
    int? middleTip,
    int? rightTip,
  }) => _service.update(
    _pageLayout.edgePatch(
      edge,
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      mode: mode,
      showLine: showLine,
      leftTip: leftTip,
      middleTip: middleTip,
      rightTip: rightTip,
    ),
  );

  @override
  Future<void> updateTitle({
    int? mode,
    int? size,
    int? topSpacing,
    int? bottomSpacing,
  }) => _service.update(
    _pageLayout.titlePatch(
      mode: mode,
      size: size,
      topSpacing: topSpacing,
      bottomSpacing: bottomSpacing,
    ),
  );

  @override
  Future<ReaderAdvancedConfig> loadAdvanced() async {
    late ReaderAdvancedConfig result;
    await _operations.run(() async => result = await _load());
    return result;
  }

  @override
  Future<void> saveAdvanced(ReaderAdvancedConfig config) {
    final snapshot = config.copy();
    return _operations.run(() => _save(snapshot));
  }

  Future<void> _write(Future<bool> result) async {
    if (!await result) throw StateError('阅读配置保存失败');
  }

  int _menuStyle(Object? value) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed != null && parsed >= 0 && parsed <= 2 ? parsed : 0;
  }

  /// 从持久化存储加载唯一一套排版；旧值只在迁移入口转换一次。
  Future<ReaderAdvancedConfig> _load() async {
    final prefs = await _preferences();
    await migrateReaderSettings(prefs);

    TapAction tap(String key, TapAction def) {
      final i = prefs.getInt('$_prefix$key');
      if (i == null || i < 0 || i >= TapAction.values.length) return def;
      return TapAction.values[i];
    }

    List<TapAction> loadTapActions() {
      final stored = prefs.getStringList('${_prefix}tap_actions_v1');
      if (stored != null && stored.length == 9) {
        final indices = stored.map(int.tryParse).toList();
        if (indices.every(
          (i) => i != null && i >= 0 && i < TapAction.values.length,
        )) {
          return indices.map((i) => TapAction.values[i!]).toList();
        }
      }
      final columns = [
        tap('left_action', TapAction.prevPage),
        tap('center_action', TapAction.toggleControls),
        tap('right_action', TapAction.nextPage),
      ];
      // 旧默认采用新九宫格；自定义三列沿用到每一行，不覆盖用户选择。
      if (columns[0] == TapAction.prevPage &&
          columns[1] == TapAction.toggleControls &&
          columns[2] == TapAction.nextPage) {
        return ReaderAdvancedConfig.defaultTapActions;
      }
      return [...columns, ...columns, ...columns];
    }

    // 尚未迁走的阅读状态条保留原四开关的默认转换，本组页面设置不参与。
    const c2DefaultsMigratedKey = 'settingsMigrated_v271';
    if (!(prefs.getBool(c2DefaultsMigratedKey) ?? false)) {
      const statusRowKeys = <String>[
        '${_prefix}show_battery',
        '${_prefix}show_time',
        '${_prefix}show_progress',
        '${_prefix}show_chapter_name',
      ];
      for (final key in statusRowKeys) {
        // 旧默认=true（开）；存量 true 视为未手动修改 → 改新默认 false（关）
        if (prefs.getBool(key) == true) {
          await prefs.setBool(key, false);
        }
      }
      await prefs.setBool(c2DefaultsMigratedKey, true);
    }

    return ReaderAdvancedConfig(
      autoPageTurn: prefs.getBool('${_prefix}auto_page_turn') ?? false,
      autoPageTurnInterval: (prefs.getDouble('${_prefix}auto_interval') ?? 10)
          .clamp(3.0, 120.0),
      autoPageTurnForward: prefs.getBool('${_prefix}auto_forward') ?? true,
      tapActions: loadTapActions(),
      // [C2 R4] 状态行四开关 load 缺省对齐构造器默认（关闭），参考该态无此信息行
      showBattery: prefs.getBool('${_prefix}show_battery') ?? false,
      showTime: prefs.getBool('${_prefix}show_time') ?? false,
      showProgress: prefs.getBool('${_prefix}show_progress') ?? false,
      showChapterName: prefs.getBool('${_prefix}show_chapter_name') ?? false,
      // [UI-fix v2.0.3 | 2026-08-08] 第①批 MoreConfig 项读取（键名=原版键）— Qoder
      screenOrientation: (prefs.getInt('screenOrientation') ?? 0).clamp(0, 5),
      keepLight: prefs.getInt('keep_light') ?? 0,
      hideStatusBar: prefs.getBool('hideStatusBar') ?? false,
      hideNavigationBar: prefs.getBool('hideNavigationBar') ?? false,
      progressBarBehavior: (prefs.getString('progressBarBehavior') == 'chapter')
          ? 'chapter'
          : 'page',
      noAnimScrollPage: prefs.getBool('noAnimScrollPage') ?? false,
      autoChangeSource: prefs.getBool('autoChangeSource') ?? true,
      selectText: prefs.getBool('selectText') ?? true,
      // [PARITY C2 M5] load 缺省对齐构造器默认（关闭），参考菜单该态无亮度条。
      brightnessMode: _brightnessMode(prefs.get('showBrightnessView')),
      brightnessOnLeft: prefs.getString('brightnessVwPos') == '0',
      showReadTitleAddition: prefs.getBool('showReadTitleAddition') ?? true,
      readBarStyle: _menuStyle(prefs.get('readBarStyle')),
      readMenuPaletteStyle: prefs.getString('readMenuPaletteStyle') ?? '',
      readMenuColorMode: prefs.getInt('readMenuColorMode') ?? 0,
      readMenuAccentColor: prefs.getInt('readMenuAccentColor') ?? 0,
      readMenuAccentColorNight: prefs.getInt('readMenuAccentColorNight') ?? 0,
      readMenuBgColor: prefs.getInt('readMenuBgColor') ?? 0,
      readMenuBgColorNight: prefs.getInt('readMenuBgColorNight') ?? 0,
      readMenuContainerColor: prefs.getInt('readMenuContainerColor') ?? 0,
      readMenuContainerColorNight:
          prefs.getInt('readMenuContainerColorNight') ?? 0,
      readMenuTextColor: prefs.getInt('readMenuTextColor') ?? 0,
      readMenuTextColorNight: prefs.getInt('readMenuTextColorNight') ?? 0,
      // [UI-fix v2.0.4 | 2026-08-08] 第②批 MoreConfig 项读取（键名=原版键，
      // 默认值对齐 pref_config_read.xml android:defaultValue）— Qoder
      volumeKeyPage: prefs.getBool('volumeKeyPage') ?? true,
      volumeKeyPageOnPlay: prefs.getBool('volumeKeyPageOnPlay') ?? false,
      mouseWheelPage: prefs.getBool('mouseWheelPage') ?? true,
      pageTouchSlop: (prefs.getInt('pageTouchSlop') ?? 0).clamp(0, 9999),
      pageTouchClick: (prefs.getInt('pageTouchClick') ?? 0).clamp(0, 399),
      readBodyToLh: prefs.getBool('readBodyToLh') ?? false,
      paddingDisplayCutouts: prefs.getBool('paddingDisplayCutouts') ?? false,
    );
  }

  /// 保存唯一一套排版；正文与菜单的日夜颜色仍保持独立。
  Future<void> _save(ReaderAdvancedConfig config) async {
    final prefs = await _preferences();

    await _write(
      prefs.setBool('${_prefix}auto_page_turn', config.autoPageTurn),
    );
    await _write(
      prefs.setDouble('${_prefix}auto_interval', config.autoPageTurnInterval),
    );
    await _write(
      prefs.setBool('${_prefix}auto_forward', config.autoPageTurnForward),
    );
    await _write(
      prefs.setStringList(
        '${_prefix}tap_actions_v1',
        config.tapActions.map((a) => a.index.toString()).toList(),
      ),
    );
    // 旧版本只能表达三列，以中间一行保留其可读取的动作。
    await _write(
      prefs.setInt('${_prefix}left_action', config.tapActions[3].index),
    );
    await _write(
      prefs.setInt('${_prefix}center_action', config.tapActions[4].index),
    );
    await _write(
      prefs.setInt('${_prefix}right_action', config.tapActions[5].index),
    );
    await _write(prefs.setBool('${_prefix}show_battery', config.showBattery));
    await _write(prefs.setBool('${_prefix}show_time', config.showTime));
    await _write(prefs.setBool('${_prefix}show_progress', config.showProgress));
    await _write(
      prefs.setBool('${_prefix}show_chapter_name', config.showChapterName),
    );
    // [UI-fix v2.0.3 | 2026-08-08] 第①批 MoreConfig 项持久化（键名=原版键）— Qoder
    await _write(prefs.setInt('screenOrientation', config.screenOrientation));
    await _write(prefs.setInt('keep_light', config.keepLight));
    await _write(prefs.setBool('hideStatusBar', config.hideStatusBar));
    await _write(prefs.setBool('hideNavigationBar', config.hideNavigationBar));
    await _write(
      prefs.setString('progressBarBehavior', config.progressBarBehavior),
    );
    await _write(prefs.setBool('noAnimScrollPage', config.noAnimScrollPage));
    await _write(prefs.setBool('autoChangeSource', config.autoChangeSource));
    await _write(prefs.setBool('selectText', config.selectText));
    await _write(
      prefs.setString('showBrightnessView', '${config.brightnessMode}'),
    );
    await _write(
      prefs.setString('brightnessVwPos', config.brightnessOnLeft ? '0' : '1'),
    );
    await _write(
      prefs.setBool('showReadTitleAddition', config.showReadTitleAddition),
    );
    await _write(prefs.setInt('readBarStyle', config.readBarStyle));
    await _write(
      prefs.setString('readMenuPaletteStyle', config.readMenuPaletteStyle),
    );
    await _write(prefs.setInt('readMenuColorMode', config.readMenuColorMode));
    await _write(
      prefs.setInt('readMenuAccentColor', config.readMenuAccentColor),
    );
    await _write(
      prefs.setInt('readMenuAccentColorNight', config.readMenuAccentColorNight),
    );
    await _write(prefs.setInt('readMenuBgColor', config.readMenuBgColor));
    await _write(
      prefs.setInt('readMenuBgColorNight', config.readMenuBgColorNight),
    );
    await _write(
      prefs.setInt('readMenuContainerColor', config.readMenuContainerColor),
    );
    await _write(
      prefs.setInt(
        'readMenuContainerColorNight',
        config.readMenuContainerColorNight,
      ),
    );
    await _write(prefs.setInt('readMenuTextColor', config.readMenuTextColor));
    await _write(
      prefs.setInt('readMenuTextColorNight', config.readMenuTextColorNight),
    );
    // [UI-fix v2.0.4 | 2026-08-08] 界面面板 + 第②批 MoreConfig 项持久化
    // （字重及第②批键名=原版键）— Qoder
    await _write(prefs.setBool('volumeKeyPage', config.volumeKeyPage));
    await _write(
      prefs.setBool('volumeKeyPageOnPlay', config.volumeKeyPageOnPlay),
    );
    await _write(prefs.setBool('mouseWheelPage', config.mouseWheelPage));
    await _write(prefs.setInt('pageTouchSlop', config.pageTouchSlop));
    await _write(prefs.setInt('pageTouchClick', config.pageTouchClick));
    await _write(prefs.setBool('readBodyToLh', config.readBodyToLh));
    await _write(
      prefs.setBool('paddingDisplayCutouts', config.paddingDisplayCutouts),
    );
  }
}

int _brightnessMode(Object? value) {
  if (value is bool) return value ? 1 : 0;
  final mode = int.tryParse('$value');
  return mode != null && mode >= 0 && mode <= 2 ? mode : 0;
}
