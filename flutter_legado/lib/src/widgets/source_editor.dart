import '../l10n/app_localization.dart';

import 'package:material_ui/material_ui.dart';

/// 书源与订阅源共用的字段描述；字段映射与保存由各自页面负责。
class SourceEditorFieldSpec {
  const SourceEditorFieldSpec(
    this.key,
    this.label, {
    this.hint,
    this.singleLine = false,
    this.required = false,
  });

  final String key;
  final String label;
  final String? hint;
  final bool singleLine;
  final bool required;
}

/// 共用描边输入、浮动标签与必填校验，代码编辑统一由顶栏提供。
class SourceEditorField extends StatelessWidget {
  const SourceEditorField({
    super.key,
    required this.spec,
    required this.controller,
    required this.focusNode,
    this.maxLines = 0,
  });

  final SourceEditorFieldSpec spec;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextFormField(
        key: ValueKey<String>('sf_${spec.key}'),
        controller: controller,
        focusNode: focusNode,
        minLines: 1,
        maxLines: spec.singleLine ? 1 : (maxLines == 0 ? null : maxLines),
        decoration: InputDecoration(
          filled: false,
          labelText: spec.required ? '${spec.label} *' : spec.label,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          alignLabelWithHint: !spec.singleLine,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          hintText: spec.hint,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        validator: spec.required
            ? (value) => (value == null || value.trim().isEmpty)
                  ? context.l10n.enterEditorField(spec.label)
                  : null
            : null,
      ),
    );
  }
}

/// 两类源编辑页共用的扁平选项区；字段与保存由页面拥有。— Codex + UI
class SourceEditorOptions extends StatelessWidget {
  const SourceEditorOptions({
    super.key,
    required this.title,
    required this.summary,
    required this.children,
  });

  final String title;
  final String summary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final border = Border(
      bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
    );
    return ListTileTheme.merge(
      shape: const RoundedRectangleBorder(),
      child: ExpansionTile(
        key: PageStorageKey<String>('source-editor-options-$title'),
        title: Text(title),
        subtitle: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
        shape: border,
        collapsedShape: border,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 输入控件的滚动偏移不能与折叠区的 bool 状态共用存储位置。
          KeyedSubtree(
            key: const PageStorageKey<String>('source-editor-option-fields'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// 已打开页签保留输入、滚动和表单状态，避免切换后失去必填校验。
class SourceEditorTab extends StatefulWidget {
  const SourceEditorTab({
    super.key,
    required this.storageKey,
    required this.children,
    this.padding = const EdgeInsets.only(bottom: 24),
  });

  final String storageKey;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  State<SourceEditorTab> createState() => _SourceEditorTabState();
}

class _SourceEditorTabState extends State<SourceEditorTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListTileTheme.merge(
      shape: const RoundedRectangleBorder(),
      child: ListView(
        key: PageStorageKey<String>(widget.storageKey),
        padding: widget.padding,
        children: widget.children,
      ),
    );
  }
}
