import '../../../app/routing/app_navigation.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/legado_app_bar.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routing/route_names.dart';
import '../../../services/app_update_service.dart';
import '../../../services/crash_log_service.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/update_dialog.dart';
import '../../../widgets/help/show_help.dart';

/// 关于页面（对齐原版 about.xml + AboutFragment）
///
/// 条目：开发人员 / 更新日志 / 检查更新；
/// 「其他」：崩溃日志 / 保存日志 / 创建堆转储 / 用户隐私与协议 / 开源许可 / 免责声明。
/// 视觉：apple-ui-designer 分组 inset 列表，去掉创意技术栈卡片与营销文案。
///
/// — UI 子代理 + UI ｜ 2026-08-13
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  static const _projectUrl = AppUpdateService.projectUrl;
  static const _contributorsUrl = '$_projectUrl/graphs/contributors';
  static const _privacyUrl =
      'https://gedoor.github.io/legado/#/md/privacyPolicy';

  bool _checkingUpdate = false;
  String _appVersion = '';
  final _updates = AppUpdateService();
  bool? _acceptsPrereleases;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppVersion();
      _loadUpdatePreference();
    });
  }

  @override
  void dispose() {
    _updates.close();
    super.dispose();
  }

  Future<void> _loadUpdatePreference() async {
    try {
      final enabled = await _updates.acceptsPrereleases();
      if (mounted) setState(() => _acceptsPrereleases = enabled);
    } catch (e) {
      if (mounted) showAppSnackBar(context, '读取更新设置失败：$e');
    }
  }

  Future<void> _setUpdatePreference(bool enabled) async {
    try {
      await _updates.setAcceptsPrereleases(enabled);
      if (mounted) setState(() => _acceptsPrereleases = enabled);
    } catch (e) {
      if (mounted) showAppSnackBar(context, '保存更新设置失败：$e');
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final package = await AppUpdateService.resolveCurrentPackage();
      final channel = switch (AppUpdateService.buildChannel) {
        'stable' => '正式版',
        'alpha' => '测试版',
        _ => '开发版',
      };
      final v = '${package.version}（${package.buildNumber}，$channel）';
      if (mounted) setState(() => _appVersion = v);
    } catch (e) {
      debugPrint('获取应用版本号失败: $e');
    }
  }

  Future<void> _launch(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(SnackBar(content: Text('已复制链接：$url')));
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _launch('${AppUpdateService.projectUrl}/releases');
        return;
      }
      final info = await _updates.check();
      if (!mounted) return;
      if (info == null) {
        showAppSnackBar(context, '当前已是所选渠道的最新版本');
        return;
      }
      await showAppUpdateDialog(context, info: info);
    } catch (e) {
      if (mounted) showAppSnackBar(context, '检查更新失败：$e');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _showMarkdown(String title, String assetPath) async {
    await showHelpDocument(context, title: title, assetPath: assetPath);
  }

  Future<void> _showUpdateLog() => _showMarkdown('更新日志', 'assets/updateLog.md');

  Future<void> _showDisclaimer() =>
      _showMarkdown('免责声明', 'assets/disclaimer.md');

  Future<void> _saveLog() async {
    try {
      final path = await CrashLogService.instance.exportLogsToFile();
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未开启日志记录，请去其他设置里打开记录日志')));
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('日志已导出：$path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存日志失败：$e')));
    }
  }

  void _createHeapDumpPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('创建堆转储暂不可用（需 Android 堆转储能力；请先开启「记录堆转储」）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(title: const Text('关于')),
      body: SettingsBody(
        child: ListView(
          // [LAYOUT_PLAN P3] 底部 bottom32 保留；列表水平边距走 SettingsBody 16dp
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SettingsGroup(
              children: [
                SettingTile(
                  title: '项目主页',
                  subtitle: 'xldgo/OpenLegado',
                  onTap: () => _launch(_projectUrl),
                ),
                SettingTile(
                  title: '开发人员',
                  subtitle: '查看本项目的 GitHub 贡献者',
                  onTap: () => _launch(_contributorsUrl),
                ),
                SettingTile(
                  title: '更新日志',
                  subtitle: _appVersion.isEmpty ? '版本 …' : '版本 $_appVersion',
                  onTap: _showUpdateLog,
                ),
                SettingTile(
                  title: '检查更新',
                  trailing: _checkingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _checkingUpdate ? null : _checkUpdate,
                ),
                if (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.windows)
                  SettingSwitchRow(
                    title: '接收测试版更新',
                    value: _acceptsPrereleases ?? false,
                    onChanged: _acceptsPrereleases == null || _checkingUpdate
                        ? null
                        : _setUpdatePreference,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              title: '其他',
              children: [
                SettingTile(
                  title: '崩溃日志',
                  onTap: () =>
                      GoRouter.of(context).pushAppRoute(AppRoutes.appLog),
                ),
                SettingTile(title: '保存日志', onTap: _saveLog),
                SettingTile(title: '创建堆转储', onTap: _createHeapDumpPlaceholder),
                SettingTile(
                  title: '用户隐私与协议',
                  onTap: () => _launch(_privacyUrl),
                ),
                SettingTile(
                  title: '开源许可',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'OpenLegado',
                    applicationVersion: _appVersion,
                    applicationLegalese: 'GNU General Public License v3.0',
                  ),
                ),
                SettingTile(title: '免责声明', onTap: _showDisclaimer),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
