import 'package:material_ui/material_ui.dart';

/// 控制器和保存状态由弹窗自己拥有，退出动画结束后自动释放。— Codex + UI
class PrivacyPasswordDialog extends StatefulWidget {
  const PrivacyPasswordDialog({
    super.key,
    required this.hasPassword,
    required this.save,
  });
  final bool hasPassword;
  final Future<bool> Function(String, String) save;
  @override
  State<PrivacyPasswordDialog> createState() => _PrivacyPasswordDialogState();
}

class _PrivacyPasswordDialogState extends State<PrivacyPasswordDialog> {
  final _current = TextEditingController(), _next = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !widget.hasPassword && _next.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final success = await widget.save(_current.text, _next.text);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = '当前密码不正确');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '密码保存失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.hasPassword ? '修改隐私密码' : '设置隐私密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.hasPassword)
            TextField(
              controller: _current,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: '当前密码'),
            ),
          TextField(
            controller: _next,
            obscureText: true,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: '新密码',
              helperText: widget.hasPassword ? '留空清除密码并关闭私密功能' : null,
              errorText: _error,
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? '保存中…' : '保存'),
        ),
      ],
    ),
  );
}
