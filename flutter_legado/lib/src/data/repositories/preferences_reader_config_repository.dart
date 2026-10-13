import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contracts/reader_config_repository.dart';
import '../../models/reader_advanced_config.dart';
import '../../models/flip_mode.dart';
import '../../services/reader_settings_migration.dart';
import '../../services/settings_write_queue.dart';

/// 沿用原偏好协议，同一实例串行执行迁移、读取与完整配置保存。
class PreferencesReaderConfigRepository implements ReaderConfigRepository {
  PreferencesReaderConfigRepository({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static const _prefix = 'reader_adv_';
  final Future<SharedPreferences> Function() _preferences;
  final SettingsWriteQueue _operations = SettingsWriteQueue();

  @override
  Future<ReaderAdvancedConfig> load() async {
    late ReaderAdvancedConfig result;
    await _operations.run(() async => result = await _load());
    return result;
  }

  @override
  Future<void> save(ReaderAdvancedConfig config) {
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

    // [UI-fix v2.0.4 | 2026-08-08] 字距旧值一次性迁移：旧版以 px 存储
    // （0~5，UI 25 档），若仅按 raw>1.0 判断会漏掉 0<raw≤1.0 的旧 px
    // 值（如 0.5px 会被当作 0.5em，渲染后放大一个数量级）。首次读取
    // 若无迁移标志，则将存量值一律按 px 语义 ÷18（默认字号）换算为
    // em 并写回 + 置标志；标志存在后直接按 em 读取，重复启动不再
    // 二次缩放（幂等）；save() 同步置标志防止新写入的 em 值被误
    // 迁移 — Qoder
    const migratedKey = '${_prefix}letter_spacing_migrated';
    if (!(prefs.getBool(migratedKey) ?? false)) {
      final legacyPx = prefs.getDouble('${_prefix}letter_spacing');
      if (legacyPx != null) {
        final em = (legacyPx / 18.0).clamp(-0.5, 1.0);
        await prefs.setDouble('${_prefix}letter_spacing', em.toDouble());
      }
      await prefs.setBool(migratedKey, true);
    }

    // [N4 偏好迁移 | 2.0.271 | 子代理] 一次性默认值迁移（幂等）：
    // C2 批（2.0.262）将两项默认值改新——R4 顶部「时间/章节名/进度」状态行
    // 四开关由默认开改默认关；R5 底栏左侧 tipFooterLeft 由 1(章节名) 改
    // 7(书名)。已安装设备上存有旧值时新默认永不生效（需手动改设置）。
    // 迁移语义：
    //   1. 仅当迁移标记 settingsMigrated_v271 缺失时执行（一次性）；
    //   2. 存量值 == 旧默认 → 改写为新默认（视为"从未手动修改"）：
    //      状态行四键 reader_adv_show_* 存量 true（旧默认开）→ 置 false；
    //      tipFooterLeft 存量 1（旧默认=章节名）→ 置 7（书名）；
    //   3. 存量值 != 旧默认（用户曾手动改过，如状态行已手动关、
    //      tipFooterLeft 已选其他项）→ 不动，尊重显式选择；
    //   4. 键缺失（未存过）→ load 缺省即新默认，无需写入。
    // 迁移完成后置标记，后续启动/读取不再覆盖用户手动修改。
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
      // tipFooterLeft 旧默认=1（章节名）；存量 1 视为未手动修改 → 改 7（书名）
      if (prefs.getInt('tipFooterLeft') == 1) {
        await prefs.setInt('tipFooterLeft', 7);
      }
      await prefs.setBool(c2DefaultsMigratedKey, true);
    }

    // 日夜统一读取正文排版键。
    double layoutDouble(String key, double def) =>
        (prefs.getDouble('$_prefix$key') ?? def).toDouble();

    double letterSpacingEm() {
      final raw = layoutDouble('letter_spacing', 0);
      return raw.clamp(-0.5, 1.0);
    }

    // [UI-fix v2.0.4 | 2026-08-08] 缩进档位兼容：新 int 键缺失时读取
    // 旧 bool 键（true→2 字符 / false→0），默认 2 字符 — Qoder
    int indentChars() {
      final v = prefs.getInt('${_prefix}paragraph_indent_chars');
      if (v != null) return v.clamp(0, 3);
      final legacy = prefs.getBool('${_prefix}paragraph_indent');
      if (legacy == null) return 2;
      return legacy ? 2 : 0;
    }

    return ReaderAdvancedConfig(
      autoPageTurn: prefs.getBool('${_prefix}auto_page_turn') ?? false,
      autoPageTurnInterval: (prefs.getDouble('${_prefix}auto_interval') ?? 10)
          .clamp(3.0, 120.0),
      autoPageTurnForward: prefs.getBool('${_prefix}auto_forward') ?? true,
      tapActions: loadTapActions(),
      paragraphSpacing: layoutDouble('paragraph_spacing', 2).clamp(0.0, 48.0),
      letterSpacing: letterSpacingEm(),
      paragraphIndent: indentChars(),
      textFullJustify: prefs.getBool('${_prefix}text_full_justify') ?? true,
      textBold: (prefs.getInt('textBold') ?? 0).clamp(0, 2),
      // [C3 斜体 | Qoder UI] 斜体（参考版行内面板开关；双基准补齐）
      italic: prefs.getBool('${_prefix}italic') ?? false,
      customTextColor: prefs.getInt('${_prefix}custom_text_color') ?? 0,
      pageMarginTop: layoutDouble('margin_top', 24).clamp(0.0, 400.0),
      pageMarginBottom: layoutDouble('margin_bottom', 24).clamp(0.0, 400.0),
      pageMarginLeft: layoutDouble('margin_left', 20).clamp(0.0, 100.0),
      pageMarginRight: layoutDouble('margin_right', 20).clamp(0.0, 100.0),
      headerPaddingTop: layoutDouble('header_padding_top', 0).clamp(0.0, 400.0),
      headerPaddingBottom: layoutDouble(
        'header_padding_bottom',
        0,
      ).clamp(0.0, 400.0),
      headerPaddingLeft: layoutDouble(
        'header_padding_left',
        16,
      ).clamp(0.0, 100.0),
      headerPaddingRight: layoutDouble(
        'header_padding_right',
        16,
      ).clamp(0.0, 100.0),
      footerPaddingTop: layoutDouble('footer_padding_top', 6).clamp(0.0, 400.0),
      footerPaddingBottom: layoutDouble(
        'footer_padding_bottom',
        6,
      ).clamp(0.0, 400.0),
      footerPaddingLeft: layoutDouble(
        'footer_padding_left',
        16,
      ).clamp(0.0, 100.0),
      footerPaddingRight: layoutDouble(
        'footer_padding_right',
        16,
      ).clamp(0.0, 100.0),
      showHeaderLine: prefs.getBool('showHeaderLine') ?? false,
      showFooterLine: prefs.getBool('showFooterLine') ?? true,
      headerMode: (prefs.getInt('headerMode') ?? 0).clamp(0, 2),
      footerMode: (prefs.getInt('footerMode') ?? 0).clamp(0, 2),
      tipHeaderLeft: prefs.getInt('tipHeaderLeft') ?? 2,
      tipHeaderMiddle: prefs.getInt('tipHeaderMiddle') ?? 0,
      tipHeaderRight: prefs.getInt('tipHeaderRight') ?? 3,
      // [C2 R5] load 缺省对齐构造器默认（7=书名）
      tipFooterLeft: prefs.getInt('tipFooterLeft') ?? 7,
      tipFooterMiddle: prefs.getInt('tipFooterMiddle') ?? 0,
      tipFooterRight: prefs.getInt('tipFooterRight') ?? 6,
      titleMode: (prefs.getInt('titleMode') ?? 0).clamp(0, 2),
      titleSize: (prefs.getInt('titleSize') ?? 0).clamp(0, 20),
      titleTopSpacing: (prefs.getInt('titleTopSpacing') ?? 0).clamp(0, 100),
      titleBottomSpacing: (prefs.getInt('titleBottomSpacing') ?? 0).clamp(
        0,
        100,
      ),
      titleFont: prefs.getString('titleFont') ?? '',
      // [C2 R4] 状态行四开关 load 缺省对齐构造器默认（关闭），参考该态无此信息行
      showBattery: prefs.getBool('${_prefix}show_battery') ?? false,
      showTime: prefs.getBool('${_prefix}show_time') ?? false,
      showProgress: prefs.getBool('${_prefix}show_progress') ?? false,
      showChapterName: prefs.getBool('${_prefix}show_chapter_name') ?? false,
      flipMode: FlipMode.fromIndex(
        prefs.getInt('flip_mode') ?? FlipMode.slide.index,
      ),
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
      doubleHorizontalPage: (prefs.getInt('doubleHorizontalPage') ?? 0).clamp(
        0,
        3,
      ),
      useZhLayout: prefs.getBool('useZhLayout') ?? false,
      hangingPunctuation: prefs.getBool('hangingPunctuation') ?? false,
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
    // 边距和排版只保存一套。
    await _write(
      prefs.setDouble('${_prefix}paragraph_spacing', config.paragraphSpacing),
    );
    await _write(
      prefs.setDouble('${_prefix}letter_spacing', config.letterSpacing),
    );
    // [UI-fix v2.0.4 | 2026-08-08] 写入即为 em 语义，同步置迁移标志，
    // 避免 save 先于 load 时新值被误当旧 px 二次换算 — Qoder
    await _write(prefs.setBool('${_prefix}letter_spacing_migrated', true));
    // [UI-fix v2.0.4 | 2026-08-08] 缩进档位写新 int 键（旧 bool 键保留不再更新）— Qoder
    await _write(
      prefs.setInt('${_prefix}paragraph_indent_chars', config.paragraphIndent),
    );
    await _write(
      prefs.setBool('${_prefix}text_full_justify', config.textFullJustify),
    );
    await _write(prefs.setDouble('${_prefix}margin_top', config.pageMarginTop));
    await _write(
      prefs.setDouble('${_prefix}margin_bottom', config.pageMarginBottom),
    );
    await _write(
      prefs.setDouble('${_prefix}margin_left', config.pageMarginLeft),
    );
    await _write(
      prefs.setDouble('${_prefix}margin_right', config.pageMarginRight),
    );
    await _write(
      prefs.setDouble('${_prefix}header_padding_top', config.headerPaddingTop),
    );
    await _write(
      prefs.setDouble(
        '${_prefix}header_padding_bottom',
        config.headerPaddingBottom,
      ),
    );
    await _write(
      prefs.setDouble(
        '${_prefix}header_padding_left',
        config.headerPaddingLeft,
      ),
    );
    await _write(
      prefs.setDouble(
        '${_prefix}header_padding_right',
        config.headerPaddingRight,
      ),
    );
    await _write(
      prefs.setDouble('${_prefix}footer_padding_top', config.footerPaddingTop),
    );
    await _write(
      prefs.setDouble(
        '${_prefix}footer_padding_bottom',
        config.footerPaddingBottom,
      ),
    );
    await _write(
      prefs.setDouble(
        '${_prefix}footer_padding_left',
        config.footerPaddingLeft,
      ),
    );
    await _write(
      prefs.setDouble(
        '${_prefix}footer_padding_right',
        config.footerPaddingRight,
      ),
    );
    await _write(prefs.setBool('showHeaderLine', config.showHeaderLine));
    await _write(prefs.setBool('showFooterLine', config.showFooterLine));
    await _write(prefs.setInt('headerMode', config.headerMode));
    await _write(prefs.setInt('footerMode', config.footerMode));
    await _write(prefs.setInt('tipHeaderLeft', config.tipHeaderLeft));
    await _write(prefs.setInt('tipHeaderMiddle', config.tipHeaderMiddle));
    await _write(prefs.setInt('tipHeaderRight', config.tipHeaderRight));
    await _write(prefs.setInt('tipFooterLeft', config.tipFooterLeft));
    await _write(prefs.setInt('tipFooterMiddle', config.tipFooterMiddle));
    await _write(prefs.setInt('tipFooterRight', config.tipFooterRight));
    await _write(prefs.setInt('titleMode', config.titleMode));
    await _write(prefs.setInt('titleSize', config.titleSize));
    await _write(prefs.setInt('titleTopSpacing', config.titleTopSpacing));
    await _write(prefs.setInt('titleBottomSpacing', config.titleBottomSpacing));
    await _write(prefs.setString('titleFont', config.titleFont));
    await _write(prefs.setBool('${_prefix}show_battery', config.showBattery));
    await _write(prefs.setBool('${_prefix}show_time', config.showTime));
    await _write(prefs.setBool('${_prefix}show_progress', config.showProgress));
    await _write(
      prefs.setBool('${_prefix}show_chapter_name', config.showChapterName),
    );
    await _write(prefs.setInt('flip_mode', config.flipMode.index));
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
    await _write(prefs.setBool('${_prefix}italic', config.italic));
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
    await _write(prefs.setInt('textBold', config.textBold));
    await _write(
      prefs.setInt('${_prefix}custom_text_color', config.customTextColor),
    );
    await _write(prefs.setBool('volumeKeyPage', config.volumeKeyPage));
    await _write(
      prefs.setBool('volumeKeyPageOnPlay', config.volumeKeyPageOnPlay),
    );
    await _write(prefs.setBool('mouseWheelPage', config.mouseWheelPage));
    await _write(
      prefs.setInt('doubleHorizontalPage', config.doubleHorizontalPage),
    );
    await _write(prefs.setBool('useZhLayout', config.useZhLayout));
    await _write(
      prefs.setBool('hangingPunctuation', config.hangingPunctuation),
    );
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
