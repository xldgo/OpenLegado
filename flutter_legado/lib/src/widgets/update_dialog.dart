import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';
import 'app_snack_bar.dart';

/// 手动检查始终允许查看更新；下载交给系统浏览器，不自行安装。
Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppUpdateInfo info,
}) => showDialog<void>(
  context: context,
  builder: (context) => _UpdateDialog(info: info),
);

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.info});
  final AppUpdateInfo info;

  Future<void> _open(BuildContext context, String url) async {
    try {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('无法打开链接');
      }
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, '打开下载链接失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${info.version}${info.isPrerelease ? ' Alpha' : ''}（${info.buildNumber}）',
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: SelectableText(
          info.updateLog.trim().isEmpty ? '暂无更新说明' : info.updateLog,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: () => _open(context, info.releaseUrl),
        child: const Text('发布页面'),
      ),
      FilledButton(
        onPressed: () => _open(context, info.downloadUrl),
        child: const Text('下载'),
      ),
    ],
  );
}
