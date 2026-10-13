// source_edit_screen.dart 的分域 part 文件（体检 §三.16 超长文件拆分，方法原样搬移）。
// extension _SourceEditBuilders 承载：页签表单、设置段与字段分组构建。
// 同 library 内可访问 State 私有字段；生命周期（initState/dispose/build）留在主类。
part of 'source_edit_screen.dart';

// ConsumerState.ref 为 protected 成员，extension 分区无法继承其访问域；
// 本文件所有方法均运行于 State 自身（this），受保护访问语义安全。
// ignore_for_file: invalid_use_of_protected_member

extension _SourceEditBuilders on _SourceEditScreenState {
  Widget _buildEditTab(String name, List<Widget> sections) {
    return SourceEditorTab(storageKey: 'source_edit_$name', children: sections);
  }

  /// 可折叠「设置」段（[B2-C2 2-8] 扁平化对齐参考版 ref 09：取消分组卡片
  /// 外壳，改为平铺段落 + 底部细分割线；收起态显示「设置」+ 摘要「类型 |
  /// 启用 | 发现 | CookieJar | 段评 | 事件监听 | 定制按钮」+ 展开箭头；
  /// 展开显示 类型：下拉 + 开关，交互行为与文案不变）
  Widget _buildSettingsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    Widget checkChip(String label, bool value, ValueChanged<bool> onChanged) {
      return SizedBox(
        width: 132,
        child: CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: const TextStyle(fontSize: 14)),
          value: value,
          onChanged: (v) => setState(() => onChanged(v ?? false)),
        ),
      );
    }

    // 摘要（对齐原版 tvOptionsSummary：类型 + 勾选开关 join(" | ")）
    final summaryParts = <String>[
      _SourceEditScreenState._typeLabels(context.l10n)[_bookSourceType],
    ];
    void addSummary(String label, bool checked) {
      if (checked) summaryParts.add(label);
    }

    addSummary(context.l10n.editorEnable, _enabled);
    addSummary(context.l10n.discover, _enabledExplore);
    addSummary('CookieJar', _cookieJar);
    addSummary(context.l10n.editorReviews, _reviewEnabled);
    addSummary(context.l10n.editorEventListener, _eventListener);
    addSummary(context.l10n.editorCustomButton, _customButton);
    final summary = summaryParts.join(' | ');

    return Container(
      // [B2-C2 2-8] 扁平化：取消卡片外壳，全宽平铺 + 底部细分割线收段
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Theme.of(context).dividerTheme.color ??
                colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 收起态 header：对齐原版 options_header（minHeight 48dp、
          // paddingStart 12dp / paddingEnd 4dp、内层 paddingVertical 4dp、
          // 「设置」16sp + 摘要 12sp 单行 + 展开箭头 40dp）
          InkWell(
            onTap: () => setState(() => _settingsExpanded = !_settingsExpanded),
            // Semantics：合并节点文案对齐原版「设置, 摘要, 展开/收起」
            child: Semantics(
              label: context.l10n.editorSettingsSummary(
                summary,
                _settingsExpanded
                    ? context.l10n.editorCollapse
                    : context.l10n.editorExpand,
              ),
              button: true,
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.settings,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                summary,
                                // 对齐原版 tv_options_summary：单行省略
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _settingsExpanded
                                ? Symbols.expand_less_rounded
                                : Symbols.expand_more_rounded,
                            size: 24,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_settingsExpanded) ...[
            // 展开内容：对齐原版 options_content（类型行 minHeight 48dp +
            // Flexbox 勾选框，paddingHorizontal 12/8、paddingBottom 4）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownMenu<int>(
                      initialSelection: _bookSourceType,
                      selectOnly: true,
                      expandedInsets: EdgeInsets.zero,
                      label: Text(context.l10n.editorType),
                      onSelected: (v) =>
                          setState(() => _bookSourceType = v ?? 0),
                      dropdownMenuEntries: [
                        for (
                          var i = 0;
                          i < _SourceEditScreenState._typeCount;
                          i++
                        )
                          DropdownMenuEntry(
                            value: i,
                            label: _SourceEditScreenState._typeLabels(
                              context.l10n,
                            )[i],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Wrap(
                children: [
                  checkChip(
                    context.l10n.editorEnable,
                    _enabled,
                    (v) => _enabled = v,
                  ),
                  checkChip(
                    context.l10n.discover,
                    _enabledExplore,
                    (v) => _enabledExplore = v,
                  ),
                  checkChip('CookieJar', _cookieJar, (v) => _cookieJar = v),
                  checkChip(
                    context.l10n.editorReviews,
                    _reviewEnabled,
                    (v) => _reviewEnabled = v,
                  ),
                  checkChip(
                    context.l10n.editorEventListener,
                    _eventListener,
                    (v) => _eventListener = v,
                  ),
                  checkChip(
                    context.l10n.editorCustomButton,
                    _customButton,
                    (v) => _customButton = v,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 页签直接展示字段，只有段评等页内子分组保留标题。
  Widget _buildFormSection(
    List<SourceEditorFieldSpec> fields, {
    String? title,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          )
        else
          const SizedBox(height: 12),
        for (final field in fields) _buildField(field),
      ],
    );
  }

  /// 描边字段使用内置浮动标签，多行输入向顶部对齐，内容增长时自动展开。
  Widget _buildField(SourceEditorFieldSpec field) {
    _fieldLabels[field.key] = field.label;
    return KeyedSubtree(
      key: _fieldKeys.putIfAbsent(field.key, GlobalKey.new),
      child: SourceEditorField(
        spec: field,
        controller: _ctrl(field.key),
        focusNode: _focus(field.key),
      ),
    );
  }
}
