// reader_config_panel.dart 的 part 文件（体检 §三.16 超长文件拆分）。
// extension _ReaderConfigBuilders 承载 build 之后的各区块构建方法（原样搬移）；生命周期/build 留在主类。
part of 'reader_config_panel.dart';

// ConsumerState.ref 为 protected 成员，extension 分区无法继承其访问域；
// 本文件所有方法均运行于 State 自身（this），受保护访问语义安全。
// ignore_for_file: invalid_use_of_protected_member

extension _ReaderConfigBuilders on _ReaderConfigPanelState {
  Widget _sectionTitle(String title, IconData icon) {
    // 分组标题与设置行保持相同的文字起点。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ===== 翻页模式 =====

  Widget _buildFlipMode() {
    final selected = ref.watch(
      readerNotifierProvider.select((state) => state.pageTurnMode),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context.l10n.flipMode, Icons.auto_stories_outlined),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SegmentedButton<PageTurnMode>(
            segments: [
              for (final mode in const [
                PageTurnMode.simulate,
                PageTurnMode.slide,
                PageTurnMode.cover,
                PageTurnMode.none,
                PageTurnMode.scroll,
              ])
                ButtonSegment(
                  value: mode,
                  label: Text(switch (mode) {
                    PageTurnMode.simulate => context.l10n.readerSimulation,
                    PageTurnMode.slide => context.l10n.readerSlide,
                    PageTurnMode.cover => context.l10n.coverMode,
                    PageTurnMode.none => context.l10n.noneMode,
                    PageTurnMode.scroll => context.l10n.readerScroll,
                  }),
                  icon: Text(mode.icon),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (sel) => _savePageTurnMode(sel.first),
          ),
        ),
      ],
    );
  }

  // ===== 自动翻页 =====

  Widget _buildAutoPageTurn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context.l10n.readerAutoPageTurn, Icons.timer_outlined),
        SettingSwitchRow(
          title: '启用自动翻页',
          value: _autoPageTurn.enabled,
          onChanged: (v) {
            _saveOperation(
              () => ref
                  .read(readerSettingsRepositoryProvider)
                  .updateAutoPageTurn(enabled: v),
            );
          },
        ),
        if (_autoPageTurn.enabled) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '间隔 ${_autoPageTurn.intervalSeconds.toStringAsFixed(0)} 秒',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Expanded(
                  child: Slider(
                    value: _autoPageTurn.intervalSeconds,
                    min: 3,
                    max: 120,
                    divisions: 117,
                    onChanged: (v) {
                      _saveOperation(
                        () => ref
                            .read(readerSettingsRepositoryProvider)
                            .updateAutoPageTurn(intervalSeconds: v),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('翻页方向', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(context.l10n.nextChapter),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text(context.l10n.previousChapter),
                      ),
                    ],
                    selected: {_autoPageTurn.forward},
                    onSelectionChanged: (sel) {
                      _saveOperation(
                        () => ref
                            .read(readerSettingsRepositoryProvider)
                            .updateAutoPageTurn(forward: sel.first),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ===== 点击区域 =====

  Widget _buildTapZones() {
    const positions = ['左上', '上中', '右上', '左中', '中间', '右中', '左下', '下中', '右下'];
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle(
                context.l10n.readerTapAreas,
                Icons.touch_app_outlined,
              ),
            ),
            IconButton(
              tooltip: '恢复默认点击区域',
              icon: const Icon(Icons.restore),
              onPressed: () {
                _saveOperation(
                  () => ref
                      .read(readerSettingsRepositoryProvider)
                      .updateInteraction(
                        tapActions: ReaderInteractionSettings.defaultTapActions,
                      ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Text('点击任意区域更换动作', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 1,
                child: Column(
                  spacing: 6,
                  children: [
                    for (var row = 0; row < 3; row++)
                      Expanded(
                        child: Row(
                          spacing: 6,
                          children: [
                            for (var column = 0; column < 3; column++)
                              Expanded(
                                child: _tapZoneCell(
                                  row * 3 + column,
                                  positions[row * 3 + column],
                                  colors,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tapZoneCell(int index, String position, ColorScheme colors) {
    final action = _interaction.tapActions[index];
    final (icon, label) = switch (action) {
      TapAction.none => (Icons.block_outlined, context.l10n.readerNoAction),
      TapAction.prevPage => (Icons.arrow_back, context.l10n.readerPreviousPage),
      TapAction.nextPage => (Icons.arrow_forward, context.l10n.readerNextPage),
      TapAction.toggleControls => (Icons.menu, context.l10n.readerMenu),
      TapAction.openCatalog => (Icons.list, context.l10n.catalog),
    };
    final menuAction = action == TapAction.toggleControls;
    return AppMenuAnchor<TapAction>(
      itemBuilder: (_) => [
        for (final option in TapAction.values)
          AppMenuItem(
            value: option,
            checked: option == action,
            child: Text(option.label),
          ),
      ],
      onSelected: (value) {
        final actions = List<TapAction>.of(_interaction.tapActions);
        actions[index] = value;
        _saveOperation(
          () => ref
              .read(readerSettingsRepositoryProvider)
              .updateInteraction(tapActions: actions),
        );
      },
      builder: (_, controller, _) => SizedBox.expand(
        child: Tooltip(
          message: '$position：$label',
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(8),
              backgroundColor: menuAction
                  ? colors.tertiaryContainer
                  : colors.secondaryContainer,
              foregroundColor: menuAction
                  ? colors.onTertiaryContainer
                  : colors.onSecondaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== 段落间距 =====

  Widget _buildParagraphSpacing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('段落间距', Icons.format_line_spacing_outlined),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                context.l10n.fontSmall,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Expanded(
                child: Slider(
                  value: _textLayout.paragraphSpacing,
                  min: 0,
                  max: 48,
                  divisions: 16,
                  label: _textLayout.paragraphSpacing.toStringAsFixed(0),
                  onChanged: (v) {
                    _saveTextLayout(
                      () => ref
                          .read(readerSettingsRepositoryProvider)
                          .updateTextLayout(paragraphSpacing: v),
                    );
                  },
                ),
              ),
              Text(
                context.l10n.fontLarge,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${_textLayout.paragraphSpacing.toStringAsFixed(0)}px',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== 字体与排版（对标原版 TextFontStyleDialog + ReadBookConfig） =====

  Widget _buildTypography() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('字体与排版', Icons.text_fields),
        // 字体选择：跳转字体管理页，返回后触发阅读器重新加载字体
        SettingTile(
          dense: true,
          icon: Icons.font_download_outlined,
          title: '阅读字体',
          subtitle: _fontLabel ?? context.l10n.readerDefaultFont,
          onTap: () async {
            await Navigator.pushNamed(context, AppRoutes.fonts);
            if (!mounted) return;
            await _loadReaderSettings();
          },
        ),
        // 字距调节（对标原版 ReadBookConfig.letterSpacing）
        // [UI-fix v2.0.4 | 2026-08-08] 语义升级为 em：-0.5~1.0 步长 0.02
        // （对标原版 dsbTextLetterSpacing (it-50)/100）— Qoder
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text('字距', style: Theme.of(context).textTheme.titleMedium),
              Expanded(
                child: Slider(
                  value: _textLayout.letterSpacing.clamp(-0.5, 1.0),
                  min: -0.5,
                  max: 1.0,
                  divisions: 75,
                  label: _textLayout.letterSpacing.toStringAsFixed(2),
                  onChanged: (v) {
                    _saveTextLayout(
                      () => ref
                          .read(readerSettingsRepositoryProvider)
                          .updateTextLayout(letterSpacing: v),
                    );
                  },
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  _textLayout.letterSpacing.toStringAsFixed(2),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
        // 首行缩进（对标原版 tvTextIndent 缩进选择器）
        // [UI-fix v2.0.4 | 2026-08-08] bool 开关升级为 0-3 字符档位 — Qoder
        SettingMenuRow<int>(
          title: '首行缩进',
          value: _textLayout.paragraphIndent,
          options: {
            0: context.l10n.readerIndentNone,
            1: context.l10n.readerIndentOne,
            2: context.l10n.readerIndentTwo,
            3: context.l10n.readerIndentThree,
          },
          onChanged: (value) {
            _saveTextLayout(
              () => ref
                  .read(readerSettingsRepositoryProvider)
                  .updateTextLayout(paragraphIndent: value),
            );
          },
        ),
      ],
    );
  }

  // ===== 更多配置（对标原版 MoreConfigDialog） =====

  /// 旧面板入口复用相同分组，完整设置页按职责分别展示。
  Widget _buildMoreConfig() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildTypographyOptions(),
      _buildInteractionOptions(),
      _buildScreenOptions(),
      _buildSystemBarOptions(),
      _buildDoublePageOptions(),
      _buildContentOptions(),
      _buildToolbarOptions(),
    ],
  );

  Widget _buildTypographyOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Icon(
              Icons.text_fields,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '中文排版',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      // 两端对齐（对标原版 MoreConfig textFullJustify）
      SettingSwitchRow(
        title: '两端对齐',
        subtitle: '正文行尾对齐（末行除外）',
        value: _textLayout.textFullJustify,
        onChanged: (v) {
          _saveTextLayout(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTextLayout(textFullJustify: v),
          );
        },
      ),
      // 中文优化分行（原版 useZhLayout；关闭后走朴素按宽断行）
      SettingSwitchRow(
        title: '中文优化分行',
        subtitle: '开启后启用中文避头尾与更优断行',
        value: _textLayout.useZhLayout,
        onChanged: (v) {
          _saveTextLayout(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateTextLayout(useZhLayout: v),
          );
        },
      ),
      if (_textLayout.useZhLayout)
        // 段首标点悬挂（原版 hangingPunctuation；已接入排版引擎）
        SettingSwitchRow(
          title: '段首标点悬挂',
          subtitle: '段首引号等标点悬挂于缩进内，使正文首字与其他段落对齐',
          value: _textLayout.hangingPunctuation,
          onChanged: (v) {
            _saveTextLayout(
              () => ref
                  .read(readerSettingsRepositoryProvider)
                  .updateTextLayout(hangingPunctuation: v),
            );
          },
        ),
    ],
  );

  Widget _buildInteractionOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('操作选项', Icons.touch_app_outlined),
      // 长按选择文本（原版 selectText：长按正文选区面板启停）
      SettingSwitchRow(
        title: context.l10n.readerSelectText,
        subtitle: '长按正文段落弹出选择面板',
        value: _interaction.selectText,
        onChanged: (v) {
          _saveOperation(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateInteraction(selectText: v),
          );
        },
      ),
      // 滚动翻页无动画（原版 noAnimScrollPage：程序化翻页去除动画）
      SettingSwitchRow(
        title: '滚动翻页无动画',
        subtitle: '点击/自动翻页直接切换不带动画',
        value: _interaction.noAnimScrollPage,
        onChanged: (v) {
          _saveOperation(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateInteraction(noAnimScrollPage: v),
          );
        },
      ),
      // 鼠标滚轮翻页（原版 mouseWheelPage；桌面端真实生效）
      SettingSwitchRow(
        title: context.l10n.readerMouseWheelPage,
        subtitle: '分页模式下滚轮上下滚动翻页',
        value: _interaction.mouseWheelPage,
        onChanged: (v) {
          _saveOperation(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateInteraction(mouseWheelPage: v),
          );
        },
      ),
      // 音量键翻页（原版 volumeKeyPage；桌面端无音量键事件）
      SettingSwitchRow(
        title: context.l10n.readerVolumeKeyPage,
        subtitle: '仅 Android 生效',
        value: _interaction.volumeKeyPage,
        onChanged: (v) {
          _saveOperation(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateInteraction(volumeKeyPage: v),
          );
        },
      ),
      if (_interaction.volumeKeyPage)
        // 朗读时音量键翻页（原版 volumeKeyPageOnPlay）
        SettingSwitchRow(
          title: context.l10n.readerVolumeKeyPageReading,
          subtitle: '仅 Android 生效',
          value: _interaction.volumeKeyPageOnPlay,
          onChanged: (v) {
            _saveOperation(
              () => ref
                  .read(readerSettingsRepositoryProvider)
                  .updateInteraction(volumeKeyPageOnPlay: v),
            );
          },
        ),
      // 滑动翻页阈值（原版 pageTouchSlop：NumberPicker 0-9999，
      // 0=系统默认值；[fix Task#41 | 2026-08-09] 已经 reader_page_view
      // 的 MediaQuery.gestureSettings 覆写拖拽识别阈值，修改即时生效）
      _moreRow(
        context.l10n.readerPageTouchSlop,
        _interaction.pageTouchSlop == 0
            ? '系统默认'
            : '${_interaction.pageTouchSlop}px',
        () {
          _showNumberDialog(
            title: context.l10n.readerPageTouchSlopDialog,
            current: _interaction.pageTouchSlop,
            max: 9999,
            onPick: (v) {
              _saveOperation(
                () => ref
                    .read(readerSettingsRepositoryProvider)
                    .updateInteraction(pageTouchSlop: v),
              );
            },
          );
        },
      ),
      // 边缘点击阈值（原版 pageTouchClick：NumberPicker 0-399，
      // 左右边缘多少距离不触发点击；[fix Task#41 | 2026-08-09] 已经
      // reader_screen._handleTap 收缩左右分区边缘死区，修改即时生效）
      _moreRow('边缘点击阈值', '${_interaction.pageTouchClick}px', () {
        _showNumberDialog(
          title: '边缘点击阈值',
          current: _interaction.pageTouchClick,
          max: 399,
          onPick: (v) {
            _saveOperation(
              () => ref
                  .read(readerSettingsRepositoryProvider)
                  .updateInteraction(pageTouchClick: v),
            );
          },
        );
      }),
    ],
  );

  Widget _buildScreenOptions({bool showTitle = true}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showTitle) _sectionTitle('屏幕与亮度', Icons.phone_android),
      // [UI-fix v2.0.3 | 2026-08-08] MoreConfig 第①批无平台依赖项：
      // 按原版 pref_config_read.xml 项序与文案补齐，每项真实生效
      // （对标 MoreConfigDialog.onSharedPreferenceChanged 事件语义）— Qoder
      // 屏幕方向（原版第 1 项 screenOrientation）
      SettingMenuRow<int>(
        title: context.l10n.readerScreenOrientation,
        value: _screen.orientation,
        options: {
          0: context.l10n.themeSystem,
          1: context.l10n.readerPortrait,
          2: context.l10n.readerLandscape,
          3: context.l10n.readerSensor,
          4: context.l10n.readerPortraitReversed,
          5: context.l10n.readerLandscapeReversed,
        },
        onChanged: (value) {
          _saveScreen(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateScreen(orientation: value),
          );
        },
      ),
      // 保持亮屏尚未接入平台能力，保留原选项并禁用。— Codex + UI
      SettingMenuRow<int>(
        title: context.l10n.readerKeepAwake,
        subtitle: '设置阅读时保持屏幕点亮的时长（待实现）',
        value: _screen.keepScreenOnSeconds,
        options: {
          0: context.l10n.readerDefault,
          60: context.l10n.readerAwakeMinute,
          300: context.l10n.readerAwakeFiveMinutes,
          600: context.l10n.readerAwakeTenMinutes,
          -1: context.l10n.readerAwakeAlways,
        },
        onChanged: null,
      ),
    ],
  );

  Widget _buildSystemBarOptions({bool showTitle = true}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showTitle) _sectionTitle('系统栏与安全区', Icons.fullscreen),
      // 隐藏状态栏（原版第 3 项：SystemUiMode 移除顶部 overlay）
      SettingSwitchRow(
        title: context.l10n.readerHideStatusBar,
        subtitle: '阅读时隐藏系统状态栏',
        value: _screen.hideStatusBar,
        onChanged: (v) {
          _saveScreen(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateScreen(hideStatusBar: v),
          );
        },
      ),
      // 隐藏导航栏（原版第 4 项：SystemUiMode 移除底部 overlay）
      SettingSwitchRow(
        title: context.l10n.readerHideNavigationBar,
        subtitle: '阅读时隐藏系统导航栏',
        value: _screen.hideNavigationBar,
        onChanged: (v) {
          _saveScreen(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateScreen(hideNavigationBar: v),
          );
        },
      ),
      // [UI-fix v2.0.4 | 2026-08-08] MoreConfig 第②批：按原版
      // pref_config_read.xml 项序与文案补齐，平台受限项以副标题
      // 灰字诚实标注（不引入新依赖）— Qoder
      // 扩展到刘海（原版 readBodyToLh）
      SettingSwitchRow(
        title: context.l10n.readerExtendCutout,
        subtitle: '正文延伸到刘海区域',
        value: _screen.extendIntoCutout,
        onChanged: (v) {
          _saveScreen(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateScreen(extendIntoCutout: v),
          );
        },
      ),
      // 填充刘海区域（原版 paddingDisplayCutouts）
      SettingSwitchRow(
        title: context.l10n.readerFillCutout,
        subtitle: '页面边距避开刘海区域',
        value: _screen.avoidDisplayCutouts,
        onChanged: (v) {
          _saveScreen(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateScreen(avoidDisplayCutouts: v),
          );
        },
      ),
    ],
  );

  Widget _buildDoublePageOptions() => SettingMenuRow<int>(
    title: context.l10n.readerDualPageMode,
    value: _pageLayout.doubleHorizontalPage,
    options: {
      0: context.l10n.readerSinglePage,
      1: context.l10n.readerDoublePage,
      2: context.l10n.readerLandscapeDoublePage,
      3: context.l10n.readerDualPageMode,
    },
    onChanged: (value) {
      _savePageLayout(
        () => ref
            .read(readerSettingsRepositoryProvider)
            .updatePageLayout(doubleHorizontalPage: value),
      );
    },
  );

  Widget _buildContentOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('内容处理', Icons.article_outlined),
      // 简繁转换（接 Rust 繁简转换 FFI，对标原版 chineseConvertType）
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.readerChineseConversion,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(context.l10n.readerNoConversion),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(context.l10n.readerToSimplified),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(context.l10n.readerToTraditional),
                ),
              ],
              selected: {_convertType},
              onSelectionChanged: (sel) async {
                final type = sel.first;
                try {
                  await ref
                      .read(readingContentServiceProvider)
                      .setChineseConvertType(type);
                  if (mounted) setState(() => _convertType = type);
                  // 转换类型变更后重新加载当前章正文
                  if (mounted) {
                    unawaited(
                      ref
                          .read(readerNotifierProvider.notifier)
                          .reloadChapterContent(),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('简繁转换设置失败: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
      // 自动换源（原版 autoChangeSource：章节加载失败自动切换书源）
      SettingSwitchRow(
        title: context.l10n.readerAutoChangeSource,
        subtitle: '章节加载失败时自动切换书源',
        value: ref
            .read(readerSettingsRepositoryProvider)
            .current
            .autoChangeSource,
        onChanged: (value) async {
          try {
            await ref
                .read(readerSettingsRepositoryProvider)
                .update(autoChangeSource: value);
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('自动换源设置保存失败，请重试')));
          }
        },
      ),
    ],
  );

  Widget _buildToolbarOptions({bool showTitle = true}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showTitle) _sectionTitle('菜单工具栏', Icons.view_quilt_outlined),
      // 进度条行为（原版第 8 项 progressBarBehavior：调章内页/调章节）
      SettingMenuRow<String>(
        title: context.l10n.readerProgressBarBehavior,
        value: _interaction.progressBarBehavior,
        options: {
          'page': context.l10n.readerAdjustChapterPage,
          'chapter': context.l10n.readerAdjustChapterIndex,
        },
        onChanged: (value) {
          _saveOperation(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateInteraction(progressBarBehavior: value),
          );
        },
      ),
      _buildBrightnessDisplayMenu(),
      SettingSwitchRow(
        title: '显示标题附加区',
        subtitle: '书名后追加章节名（待实现）',
        value: ref
            .read(readerSettingsRepositoryProvider)
            .current
            .showTitleAddition,
        onChanged: null,
      ),
    ],
  );

  List<Widget> _buildMenuThemeOptions() {
    final l10n = context.l10n;
    final night =
        _menuColorNight ?? Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final readingBackground = ref.watch(readerNotifierProvider).backgroundColor;
    return [
      SettingMenuRow<int>(
        title: l10n.readerMenuTheme,
        value: _menuTheme.mode,
        options: {
          0: l10n.readerMenuFollowApp,
          1: l10n.readerMenuFollowBackground,
          2: l10n.readerMenuCustom,
        },
        onChanged: (value) {
          _saveMenuSetting(
            () => ref
                .read(readerSettingsRepositoryProvider)
                .updateMenuTheme(mode: value),
          );
        },
      ),
      if (_menuTheme.mode != 0)
        SettingMenuRow<String>(
          title: l10n.readerMenuPalette,
          value: _menuTheme.paletteStyle,
          options: {
            '': l10n.readerMenuFollowApp,
            'tonalSpot': l10n.readerMenuTonalSpot,
            'neutral': l10n.readerMenuNeutral,
            'vibrant': l10n.readerMenuVibrant,
            'expressive': l10n.readerMenuExpressive,
            'fidelity': l10n.readerMenuFidelity,
            'content': l10n.readerMenuContent,
            'rainbow': l10n.readerMenuRainbow,
            'fruitSalad': l10n.readerMenuFruitSalad,
            'monochrome': l10n.readerMenuMonochrome,
          },
          onChanged: (value) {
            _saveMenuSetting(
              () => ref
                  .read(readerSettingsRepositoryProvider)
                  .updateMenuTheme(paletteStyle: value),
            );
          },
        ),
      if (_menuTheme.mode == 2) ...[
        SettingMenuRow<int>(
          title: l10n.readerMenuColorMode,
          value: _menuTheme.colorMode,
          options: {0: l10n.readerMenuSeedOnly, 1: l10n.readerMenuManual},
          onChanged: (value) {
            _saveMenuSetting(
              () => ref
                  .read(readerSettingsRepositoryProvider)
                  .updateMenuTheme(colorMode: value),
            );
          },
        ),
        SettingMenuRow<bool>(
          title: l10n.readerMenuEditingMode,
          value: night,
          options: {false: l10n.readerMenuDay, true: l10n.readerMenuNight},
          onChanged: (value) => setState(() => _menuColorNight = value),
        ),
        _menuColorRow(
          l10n.readerMenuAccent,
          night ? _menuTheme.accentColorNight : _menuTheme.accentColor,
          colors.primary,
          (value) => ref
              .read(readerSettingsRepositoryProvider)
              .updateMenuTheme(
                accentColor: night ? null : value,
                accentColorNight: night ? value : null,
              ),
        ),
        if (_menuTheme.colorMode != 0) ...[
          _menuColorRow(
            l10n.readerMenuBackground,
            night
                ? _menuTheme.backgroundColorNight
                : _menuTheme.backgroundColor,
            readingBackground,
            (value) => ref
                .read(readerSettingsRepositoryProvider)
                .updateMenuTheme(
                  backgroundColor: night ? null : value,
                  backgroundColorNight: night ? value : null,
                ),
          ),
          _menuColorRow(
            l10n.readerMenuContainer,
            night ? _menuTheme.containerColorNight : _menuTheme.containerColor,
            Color(
              (night
                          ? _menuTheme.backgroundColorNight
                          : _menuTheme.backgroundColor) ==
                      0
                  ? readingBackground.toARGB32()
                  : (night
                        ? _menuTheme.backgroundColorNight
                        : _menuTheme.backgroundColor),
            ),
            (value) => ref
                .read(readerSettingsRepositoryProvider)
                .updateMenuTheme(
                  containerColor: night ? null : value,
                  containerColorNight: night ? value : null,
                ),
          ),
        ],
      ],
      // 上游的标题文字覆盖独立于菜单背景模式；默认仍使用 onSurface。
      if (_menuTheme.mode != 2)
        SettingMenuRow<bool>(
          title: l10n.readerMenuEditingMode,
          value: night,
          options: {false: l10n.readerMenuDay, true: l10n.readerMenuNight},
          onChanged: (value) => setState(() => _menuColorNight = value),
        ),
      _menuColorRow(
        l10n.readerMenuTitleColor,
        night ? _menuTheme.textColorNight : _menuTheme.textColor,
        colors.onSurface,
        (value) => ref
            .read(readerSettingsRepositoryProvider)
            .updateMenuTheme(
              textColor: night ? null : value,
              textColorNight: night ? value : null,
            ),
      ),
    ];
  }

  Widget _menuColorRow(
    String title,
    int value,
    Color fallback,
    Future<void> Function(int) save,
  ) => SettingTile(
    title: title,
    showChevron: false,
    value: value == 0
        ? context.l10n.readerMenuColorDefault
        : '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
    valuePreview: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: value == 0 ? fallback : Color(value),
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    ),
    onTap: () async {
      final picked = await showDialog<int>(
        context: context,
        builder: (_) => ReaderMenuColorDialog(
          title: title,
          value: value,
          fallback: fallback,
        ),
      );
      if (!mounted || picked == null) return;
      await _saveMenuSetting(() => save(picked));
    },
  );

  Widget _buildBrightnessDisplayMenu() {
    final options = {
      0: context.l10n.readerBrightnessOff,
      1: context.l10n.readerBrightnessHorizontal,
      2: '纵向·左侧',
      3: '纵向·右侧',
    };
    final current = _brightnessControl.mode == 2
        ? (_brightnessControl.onLeft ? 2 : 3)
        : _brightnessControl.mode;
    return SettingMenuRow<int>(
      title: '亮度控件',
      value: current,
      options: options,
      onChanged: (value) {
        _saveMenuSetting(
          () => ref
              .read(readerSettingsRepositoryProvider)
              .updateBrightnessControl(
                mode: value < 2 ? value : 2,
                // 关闭或横向时保留原先的侧栏位置。
                onLeft: value >= 2 ? value == 2 : null,
              ),
        );
      },
    );
  }

  // ===== MoreConfig 第②批辅助构建方法 =====

  /// 数值输入对话框（对标原版 NumberPickerDialog，桌面端用文本输入）
  void _showNumberDialog({
    required String title,
    required int current,
    required int max,
    required ValueChanged<int> onPick,
  }) {
    final controller = TextEditingController(text: current.toString());
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(hintText: '0 ~ $max'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text) ?? current;
              Navigator.pop(dialogContext);
              onPick(v.clamp(0, max));
            },
            child: Text(dialogContext.l10n.confirm),
          ),
        ],
      ),
    );
  }

  // ===== MoreConfig 第①批辅助构建方法 =====

  /// 数值设置继续使用输入对话框，行布局复用统一设置行。
  Widget _moreRow(String title, String current, VoidCallback onTap) =>
      SettingTile(
        title: title,
        value: current,
        showChevron: false,
        onTap: onTap,
      );

  // ===== 亮度控制 =====

  Widget _buildBrightnessControl() => const ReaderBrightnessControl();
}
