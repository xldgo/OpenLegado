import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'privacy_controller.dart';

Future<bool> showPrivacyUnlock(
  BuildContext context,
  WidgetRef ref, {
  String? bookUrl,
  int? groupId,
  bool verifyOnly = false,
  bool appStart = false,
}) async {
  final controller = ref.read(privacyControllerProvider.notifier);
  await controller.refreshCapabilities();
  if (!context.mounted) return false;
  try {
    if (await controller.unlockBiometric(
      bookUrl: bookUrl,
      groupId: groupId,
      appStart: appStart,
      verifyOnly: verifyOnly,
    )) {
      return true;
    }
  } catch (_) {
    // 系统认证暂不可用时仍允许输入应用密码。
  }
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (_) => _UnlockDialog(
          verify: (password) => verifyOnly
              ? controller.verifyOnly(password)
              : controller.unlock(
                  password,
                  bookUrl: bookUrl,
                  groupId: groupId,
                  appStart: appStart,
                ),
        ),
      ) ??
      false;
}

class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog({required this.verify});
  final Future<bool> Function(String) verify;
  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final accepted = await widget.verify(_password.text);
      if (!mounted) return;
      if (accepted) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = '密码不正确');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '验证失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('验证隐私密码'),
      content: TextField(
        controller: _password,
        autofocus: true,
        obscureText: true,
        enabled: !_busy,
        decoration: InputDecoration(labelText: '密码', errorText: _error),
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? '验证中…' : '验证'),
        ),
      ],
    ),
  );
}
