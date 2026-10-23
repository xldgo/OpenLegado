import 'package:material_ui/material_ui.dart';

import '../../../widgets/app_settings_sheet.dart';
import '../../../l10n/app_localization.dart';

/// 只编辑输入；安全存储写入及成功提示由备份设置页负责。
class BackupPasswordSheet extends StatefulWidget {
  const BackupPasswordSheet({super.key});
  @override
  State<BackupPasswordSheet> createState() => _BackupPasswordSheetState();
}

class _BackupPasswordSheetState extends State<BackupPasswordSheet> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSettingsSheet(
    title: context.l10n.backupLocalPassword,
    contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    onSave: () {
      if (_password.text != _confirmation.text) {
        setState(() => _error = context.l10n.backupPasswordMismatch);
        return;
      }
      Navigator.pop(context, _password.text);
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.backupPasswordDescription),
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: context.l10n.backupNewPassword,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmation,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: context.l10n.backupConfirmPassword,
            errorText: _error,
          ),
        ),
      ],
    ),
  );
}
