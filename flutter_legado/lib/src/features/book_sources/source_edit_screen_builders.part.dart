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

  /// 基本页内的扁平选项区，与订阅源复用折叠外壳。— Codex + UI
  Widget _buildSettingsSection() {
    Widget checkChip(String label, bool value, ValueChanged<bool> onChanged) =>
        SizedBox(
          width: 132,
          child: CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(label, style: const TextStyle(fontSize: 14)),
            value: value,
            onChanged: (v) {
              setState(() => onChanged(v ?? false));
              _refreshChanges();
            },
          ),
        );
    final summary = [
      _SourceEditScreenState._typeLabels(context.l10n)[_bookSourceType],
      if (_enabled) context.l10n.editorEnable,
      if (_enabledExplore) context.l10n.discover,
      if (_cookieJar) 'CookieJar',
      if (_reviewEnabled) context.l10n.editorReviews,
      if (_eventListener) context.l10n.editorEventListener,
      if (_customButton) context.l10n.editorCustomButton,
    ].join(' | ');
    return SourceEditorOptions(
      title: context.l10n.settings,
      summary: summary,
      children: [
        DropdownMenu<int>(
          initialSelection: _bookSourceType,
          selectOnly: true,
          expandedInsets: EdgeInsets.zero,
          label: Text(context.l10n.editorType),
          onSelected: (v) {
            setState(() => _bookSourceType = v ?? 0);
            _refreshChanges();
          },
          dropdownMenuEntries: [
            for (var i = 0; i < _SourceEditScreenState._typeCount; i++)
              DropdownMenuEntry(
                value: i,
                label: _SourceEditScreenState._typeLabels(context.l10n)[i],
              ),
          ],
        ),
        Wrap(
          children: [
            checkChip(context.l10n.editorEnable, _enabled, (v) => _enabled = v),
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
      ],
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
        maxLines:
            ref.watch(generalSettingsProvider).value?.sourceEditMaxLines ?? 0,
        controller: _ctrl(field.key),
        focusNode: _focus(field.key),
      ),
    );
  }
}
