import '../../domain/contracts/reader_settings_repository.dart';
import '../../domain/models/reader_settings.dart';
import '../../domain/models/reader_text_layout_settings.dart';
import '../../domain/models/reader_page_layout_settings.dart';
import '../../domain/models/reader_screen_settings.dart';
import '../../domain/models/reader_status_strip_settings.dart';
import '../settings/reader_page_layout_codec.dart';
import '../settings/reader_interaction_codec.dart';
import '../settings/reader_menu_settings_codec.dart';
import '../../domain/models/reader_interaction_settings.dart';
import '../../domain/models/page_turn_mode.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../services/app_settings_service.dart';

/// 阅读普通偏好统一经共享服务读取、订阅及逐字段保存。— Codex + UI
class AppReaderSettingsRepository implements ReaderSettingsRepository {
  AppReaderSettingsRepository(this._service);

  static const _pageLayout = ReaderPageLayoutCodec();
  static const _interaction = ReaderInteractionCodec();
  static const _menu = ReaderMenuSettingsCodec();
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
  static const _orientation = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_screen_orientation',
  );
  static const _hideStatusBar = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_hide_status_bar',
  );
  static const _hideNavigationBar = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_hide_navigation_bar',
  );
  static const _extendIntoCutout = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_extend_into_cutout',
  );
  static const _avoidDisplayCutouts = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_avoid_display_cutouts',
  );
  static const _showBattery = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_status_show_battery',
  );
  static const _showTime = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_status_show_time',
  );
  static const _showProgress = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_status_show_progress',
  );
  static const _showChapterName = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_status_show_chapter_name',
  );
  static const _autoChangeSource = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_auto_change_source',
  );
  static const _showTitleAddition = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_show_title_addition',
  );
  static const _keepScreenOnSeconds = (
    storage: SettingsStorageKind.preferences,
    key: 'reader_keep_screen_on_seconds',
  );

  static int _keepScreenOn(int value) =>
      const {-1, 0, 60, 300, 600}.contains(value) ? value : 0;

  static const _addresses = {
    _autoChangeSource,
    _showTitleAddition,
    _keepScreenOnSeconds,
    _orientation,
    _hideStatusBar,
    _hideNavigationBar,
    _extendIntoCutout,
    _avoidDisplayCutouts,
    _showBattery,
    _showTime,
    _showProgress,
    _showChapterName,

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
    autoChangeSource: snapshot[_autoChangeSource] is bool
        ? snapshot[_autoChangeSource] as bool
        : true,
    showTitleAddition: snapshot[_showTitleAddition] is bool
        ? snapshot[_showTitleAddition] as bool
        : true,
    pageLayout: _pageLayout.decode(snapshot),
    autoPageTurn: _interaction.decodeAutoPageTurn(snapshot),
    interaction: _interaction.decodeInteraction(snapshot),
    menuTheme: _menu.decodeTheme(snapshot),
    brightnessControl: _menu.decodeBrightnessControl(snapshot),
    screen: ReaderScreenSettings(
      keepScreenOnSeconds: _keepScreenOn(
        snapshot[_keepScreenOnSeconds] is int
            ? snapshot[_keepScreenOnSeconds] as int
            : 0,
      ),
      orientation:
          (snapshot[_orientation] is int ? snapshot[_orientation] as int : 0)
              .clamp(0, 5),
      hideStatusBar: snapshot[_hideStatusBar] is bool
          ? snapshot[_hideStatusBar] as bool
          : false,
      hideNavigationBar: snapshot[_hideNavigationBar] is bool
          ? snapshot[_hideNavigationBar] as bool
          : false,
      extendIntoCutout: snapshot[_extendIntoCutout] is bool
          ? snapshot[_extendIntoCutout] as bool
          : false,
      avoidDisplayCutouts: snapshot[_avoidDisplayCutouts] is bool
          ? snapshot[_avoidDisplayCutouts] as bool
          : false,
    ),
    statusStrip: ReaderStatusStripSettings(
      showBattery: snapshot[_showBattery] is bool
          ? snapshot[_showBattery] as bool
          : false,
      showTime: snapshot[_showTime] is bool
          ? snapshot[_showTime] as bool
          : false,
      showProgress: snapshot[_showProgress] is bool
          ? snapshot[_showProgress] as bool
          : false,
      showChapterName: snapshot[_showChapterName] is bool
          ? snapshot[_showChapterName] as bool
          : false,
    ),
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
        .load({
          ..._addresses,
          ..._pageLayout.addresses,
          ..._interaction.addresses,
          ..._menu.addresses,
        })
        .then((_) {
          _loaded = true;
          return current;
        })
        .whenComplete(() => _loading = null);
  }

  @override
  Future<void> reload() async {
    await _service.reload({
      ..._addresses,
      ..._pageLayout.addresses,
      ..._interaction.addresses,
      ..._menu.addresses,
    });
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
    bool? autoChangeSource,
    bool? showTitleAddition,
  }) => _service.update({
    _mode: ?pageTurnMode?.name,
    _fontSize: ?fontSize,
    _lineHeight: ?lineHeight,
    if (fontFamily != null) _fontFamily: fontFamily.isEmpty ? null : fontFamily,
    _titleFont: ?titleFontFamily,
    _tocLoadWordCount: ?tocLoadWordCount,
    _chapterInSystemBrowser: ?chapterInSystemBrowser,
    _autoChangeSource: ?autoChangeSource,
    _showTitleAddition: ?showTitleAddition,
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
  Future<void> updateScreen({
    int? orientation,
    int? keepScreenOnSeconds,
    bool? hideStatusBar,
    bool? hideNavigationBar,
    bool? extendIntoCutout,
    bool? avoidDisplayCutouts,
  }) => _service.update({
    _orientation: ?orientation?.clamp(0, 5),
    if (keepScreenOnSeconds != null)
      _keepScreenOnSeconds: _keepScreenOn(keepScreenOnSeconds),
    _hideStatusBar: ?hideStatusBar,
    _hideNavigationBar: ?hideNavigationBar,
    _extendIntoCutout: ?extendIntoCutout,
    _avoidDisplayCutouts: ?avoidDisplayCutouts,
  });

  @override
  Future<void> updateStatusStrip({
    bool? showBattery,
    bool? showTime,
    bool? showProgress,
    bool? showChapterName,
  }) => _service.update({
    _showBattery: ?showBattery,
    _showTime: ?showTime,
    _showProgress: ?showProgress,
    _showChapterName: ?showChapterName,
  });

  @override
  Future<void> updateAutoPageTurn({
    bool? enabled,
    double? intervalSeconds,
    bool? forward,
  }) => _service.update(
    _interaction.autoPageTurnPatch(
      enabled: enabled,
      intervalSeconds: intervalSeconds,
      forward: forward,
    ),
  );

  @override
  Future<void> updateInteraction({
    List<TapAction>? tapActions,
    bool? selectText,
    bool? noAnimScrollPage,
    bool? volumeKeyPage,
    bool? volumeKeyPageOnPlay,
    bool? mouseWheelPage,
    int? pageTouchSlop,
    int? pageTouchClick,
    String? progressBarBehavior,
  }) => _service.update(
    _interaction.interactionPatch(
      tapActions: tapActions,
      selectText: selectText,
      noAnimScrollPage: noAnimScrollPage,
      volumeKeyPage: volumeKeyPage,
      volumeKeyPageOnPlay: volumeKeyPageOnPlay,
      mouseWheelPage: mouseWheelPage,
      pageTouchSlop: pageTouchSlop,
      pageTouchClick: pageTouchClick,
      progressBarBehavior: progressBarBehavior,
    ),
  );

  @override
  Future<void> updateMenuTheme({
    int? mode,
    String? paletteStyle,
    int? colorMode,
    int? accentColor,
    int? accentColorNight,
    int? backgroundColor,
    int? backgroundColorNight,
    int? containerColor,
    int? containerColorNight,
    int? textColor,
    int? textColorNight,
  }) => _service.update(
    _menu.themePatch(
      mode: mode,
      paletteStyle: paletteStyle,
      colorMode: colorMode,
      accentColor: accentColor,
      accentColorNight: accentColorNight,
      backgroundColor: backgroundColor,
      backgroundColorNight: backgroundColorNight,
      containerColor: containerColor,
      containerColorNight: containerColorNight,
      textColor: textColor,
      textColorNight: textColorNight,
    ),
  );

  @override
  Future<void> updateBrightnessControl({int? mode, bool? onLeft}) =>
      _service.update(_menu.brightnessControlPatch(mode: mode, onLeft: onLeft));
}
