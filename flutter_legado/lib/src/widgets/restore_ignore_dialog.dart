import 'package:material_ui/material_ui.dart';

import '../domain/models/restore_ignore_config.dart';

/// 恢复忽略项多选 Dialog（对齐原版 BackupConfigFragment.backupIgnore）
///
/// 勾选项在备份/恢复时经 [RestoreIgnorePrefs] 过滤偏好；
/// 「本地书籍」在调用 restore 前预过滤备份 JSON 中的本地书。
class RestoreIgnoreDialog extends StatefulWidget {
  const RestoreIgnoreDialog({super.key, required this.initial});

  final RestoreIgnoreConfig initial;

  @override
  State<RestoreIgnoreDialog> createState() => _RestoreIgnoreDialogState();
}

class _RestoreIgnoreDialogState extends State<RestoreIgnoreDialog> {
  static const _titles = <String>[
    '阅读界面配置',
    '主题模式',
    '主题配置',
    '封面规则',
    '书架布局',
    '显示订阅',
    '线程数',
    '本地书籍',
  ];
  late final Map<String, bool> _checked;

  @override
  void initState() {
    super.initState();
    // 草稿只在确定后交回调用方，勾选和取消都不修改已保存快照。
    _checked = Map.of(widget.initial.values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('恢复忽略'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '勾选后备份与恢复时跳过对应项（对齐原版）。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < RestoreIgnoreConfig.keys.length; i++)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _checked[RestoreIgnoreConfig.keys[i]] == true,
                  title: Text(_titles[i]),
                  onChanged: (v) {
                    setState(
                      () => _checked[RestoreIgnoreConfig.keys[i]] = v == true,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, RestoreIgnoreConfig(_checked)),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
