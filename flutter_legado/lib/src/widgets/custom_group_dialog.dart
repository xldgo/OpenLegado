import 'package:material_ui/material_ui.dart';

import '../l10n/app_localization.dart';

/// 自定义源分组对话框（对标原版 dialog_custom_group.xml：
/// 添加分组开关 + 分组名称输入）
///
/// 书源/订阅源/替换规则导入确认页共用；
/// controller 生命周期绑定对话框子树，随子树卸载统一释放
/// （避免退场动画期间 dispose 引发框架断言）；
/// 确定返回（分组名, 是否添加分组），取消返回 null
class CustomGroupDialog extends StatefulWidget {
  final String initialName;
  final bool initialAddGroup;

  const CustomGroupDialog({
    super.key,
    required this.initialName,
    required this.initialAddGroup,
  });

  @override
  State<CustomGroupDialog> createState() => _CustomGroupDialogState();
}

class _CustomGroupDialogState extends State<CustomGroupDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  late bool _addGroup = widget.initialAddGroup;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.customSourceGroupName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.addGroup),
            subtitle: Text(context.l10n.addGroupModeHint),
            value: _addGroup,
            onChanged: (v) => setState(() => _addGroup = v),
          ),
          TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: context.l10n.groupName),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (_controller.text.trim(), _addGroup)),
          child: Text(context.l10n.confirm),
        ),
      ],
    );
  }
}
