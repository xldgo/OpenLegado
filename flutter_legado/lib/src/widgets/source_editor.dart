import '../l10n/app_localization.dart';

import 'package:material_ui/material_ui.dart';

/// 书源与订阅源共用的字段描述；字段映射与保存由各自页面负责。
class SourceEditorFieldSpec {
  const SourceEditorFieldSpec(
    this.key,
    this.label, {
    this.hint,
    this.maxLines = 2,
    this.required = false,
  });

  final String key;
  final String label;
  final String? hint;
  final int maxLines;
  final bool required;
}

/// 共用描边输入、浮动标签与必填校验，代码编辑统一由顶栏提供。
class SourceEditorField extends StatelessWidget {
  const SourceEditorField({
    super.key,
    required this.spec,
    required this.controller,
    required this.focusNode,
  });

  final SourceEditorFieldSpec spec;
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey<String>('sf_${spec.key}'),
        controller: controller,
        focusNode: focusNode,
        minLines: 1,
        maxLines: spec.maxLines,
        decoration: InputDecoration(
          filled: false,
          labelText: spec.required ? '${spec.label} *' : spec.label,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          alignLabelWithHint: spec.maxLines > 1,
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
    return ListView(
      key: PageStorageKey<String>(widget.storageKey),
      padding: widget.padding,
      children: widget.children,
    );
  }
}
