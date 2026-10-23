import 'backup_password_sheet.dart';
import '../../../widgets/bottom_sheet_widget.dart';
import '../../../app/routing/app_navigation.dart';

import '../../../providers/backup_provider.dart';
import '../../../providers/restored_settings_provider.dart';
import '../../../l10n/app_localization.dart';
import '../../../widgets/app_menu.dart';

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../constants/pref_keys.dart';
import '../../../domain/models/restore_ignore_config.dart';
import '../../../domain/models/webdav_probe_result.dart';
import '../../../l10n/app_strings.dart';
import '../../../providers/providers.dart';
import '../../../providers/sync/sync_notifier.dart';
import '../../../app/routing/route_names.dart';
import '../../../providers/backup_settings_provider.dart';
import '../../../providers/restore_ignore_provider.dart';
import '../../../services/settings_service.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/help/help_assets.dart';
import '../../../widgets/help/show_help.dart';
import '../../../widgets/restore_ignore_dialog.dart';

/// WebDAV 连接测试状态（差异清单 C7「测试配置」行）
///
/// — full-stack-engineer + UI ｜ 2026-09-10
enum _WebDavTestStatus { notTested, testing, success, failed }

/// 备份与恢复（对齐 BackupConfigFragment + pref_config_backup.xml）
///
/// 结构：
/// 1. WebDav 设置：地址/账号/密码/子目录/设备名/同步进度（含增强）
/// 2. 备份与恢复：备份路径/备份/恢复/恢复忽略/仅保留最新/自动检查
///
/// 顶栏菜单对标 backup_restore.xml：帮助、导入旧版数据、日志。
/// 恢复项长按 → 本地恢复（对标 web_dav_restore.onLongClick）。
///
/// 路由仍为 [AppRoutes.webdavSettings]（历史路径兼容）。
///
/// — UI 子代理 + UI ｜ 2026-08-13
class WebDavSettingsScreen extends ConsumerStatefulWidget {
  const WebDavSettingsScreen({super.key});

  @override
  ConsumerState<WebDavSettingsScreen> createState() =>
      _WebDavSettingsScreenState();
}

class _WebDavSettingsScreenState extends ConsumerState<WebDavSettingsScreen> {
  SettingsService get _settings => ref.read(settingsProvider);
  static String _pendingDescription(String description) => '$description\n待实现';

  Future<void> _saveBackupPreference(Future<void> Function() save) async {
    try {
      await save();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('备份设置保存失败，请重试')));
      }
    }
  }

  String get _url => ref.read(syncNotifierProvider).webDavUrl;
  String get _user => ref.read(syncNotifierProvider).webDavUsername;
  String get _pass => ref.read(syncNotifierProvider).webDavPassword;
  String get _dir => ref.read(syncNotifierProvider).remoteDir;
  String get _device => ref.read(syncNotifierProvider).deviceName;
  String get _backupPath =>
      ref.read(backupSettingsRepositoryProvider).current.backupPath;
  bool _onlyLatestBackup = true;
  bool _autoCheckNewBackup = true;
  bool _busy = false;
  bool _hasBackupPassword = false;
  bool _savingConnection = false;

  /// 「测试配置」行连接测试状态（差异清单 C7）
  _WebDavTestStatus _testStatus = _WebDavTestStatus.notTested;

  @override
  void initState() {
    super.initState();
    unawaited(
      _loadAll().catchError((Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('备份设置读取失败，请重试')));
        }
      }),
    );
  }

  Future<void> _loadAll() async {
    final notifier = ref.read(syncNotifierProvider.notifier);
    await notifier.loadConfig();
    final password = await ref.read(backupPasswordStoreProvider).read();
    final onlyLatest = await _settings.getBoolPref(
      PrefKeys.onlyLatestBackup,
      defaultValue: true,
    );
    final autoCheck = await _settings.getBoolPref(
      PrefKeys.autoCheckNewBackup,
      defaultValue: true,
    );
    if (!mounted) return;
    setState(() {
      _hasBackupPassword = password != null && password.isNotEmpty;
      _onlyLatestBackup = onlyLatest;
      _autoCheckNewBackup = autoCheck;
    });
  }

  Future<void> _saveWebDav({
    String? url,
    String? username,
    String? password,
    String? remoteDir,
  }) async {
    setState(() => _savingConnection = true);
    try {
      await ref
          .read(syncNotifierProvider.notifier)
          .saveConfig(
            url ?? _url,
            username ?? _user,
            password ?? _pass,
            remoteDir ?? _dir,
            deviceName: _device,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('WebDAV 连接保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _savingConnection = false);
    }
  }

  Future<void> _editTextPref({
    required String title,
    required String initial,
    required Future<void> Function(String) onSaved,
    bool obscure = false,
    String? hint,
  }) async {
    if (_savingConnection) return;
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        // [LAYOUT_PLAN P3] Dialog 容器 surfaceContainer 圆角 28dp（全局标尺，对齐 dialogTheme）
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ctx.l10n.confirm),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await onSaved(result);
  }

  Future<void> _editBackupPassword() async {
    final value = await AppBottomSheet.showContent<String>(
      context: context,
      builder: (_) => const BackupPasswordSheet(),
    );
    if (value == null || !mounted) return;
    try {
      await ref.read(backupPasswordStoreProvider).write(value);
      if (mounted) setState(() => _hasBackupPassword = value.isNotEmpty);
    } catch (_) {
      if (mounted) _showResult(context.l10n.backupPasswordSaveFailed);
    }
  }

  Future<void> _pickBackupPath() async {
    final picked = await FilePicker.getDirectoryPath(dialogTitle: '选择备份路径');
    if (picked == null) return;
    await _saveBackupPreference(
      () =>
          ref.read(backupSettingsRepositoryProvider).update(backupPath: picked),
    );
  }

  Future<void> _doLocalBackup() async {
    final service = ref.read(backupServiceProvider);
    final settings = ref.read(backupSettingsRepositoryProvider);
    final sync = ref.read(syncNotifierProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final hasCloud = ref.read(syncNotifierProvider).isConfigured;
    await _runWithProgress('备份中…', () async {
      var directory = settings.current.backupPath;
      if (directory.isEmpty) {
        final picked = await FilePicker.getDirectoryPath();
        if (picked == null) return;
        directory = picked;
        await settings.update(backupPath: directory);
      }
      final path = await service.backupLocal(
        directory,
        includeCloudCredentials: settings.current.includeCloudCredentials,
      );
      String? warning;
      if (hasCloud) {
        await sync.backupToWebDav(localPath: path);
        final cloud = container.read(syncNotifierProvider);
        warning = cloud.status == SyncStatus.error
            ? '云端备份失败：${cloud.error}'
            : cloud.error;
      }
      _showResult(
        '${AppStrings.backupSuccess}：$path${warning == null ? '' : '\n$warning'}',
      );
    });
  }

  /// 默认恢复从WebDAV下载，长按从本地文件恢复。
  Future<void> _doRestore() async {
    if (!ref.read(syncNotifierProvider).isConfigured) {
      _showResult('未配置 WebDAV，请长按「恢复」从本地恢复');
      return;
    }
    final sync = ref.read(syncNotifierProvider.notifier);
    final service = ref.read(backupServiceProvider);
    final refresher = ref.read(restoredSettingsRefresherProvider);
    List<String>? names;
    await _runWithProgress('读取备份…', () async {
      names = await service.listRemoteBackups(sync.connection);
    });
    if (!mounted) return;
    final backups = names;
    if (backups == null) return;
    if (backups.isEmpty) {
      _showResult(context.l10n.backupNoRemote);
      return;
    }
    final selected = await AppBottomSheet.show<String>(
      context: context,
      title: context.l10n.backupSelectRemote,
      children: [
        for (final name in backups)
          ListTile(
            title: Text(name),
            onTap: () => Navigator.pop(context, name),
          ),
      ],
    );
    if (selected == null || !mounted) return;
    await _runWithProgress('恢复中…', () async {
      final message = await sync.restoreFromWebDav(fileName: selected);
      final failures = await refresher.refresh();
      _showResult(message, failures);
    });
  }

  Future<void> _doRestoreFromLocal() async {
    final service = ref.read(backupServiceProvider);
    final refresher = ref.read(restoredSettingsRefresherProvider);
    final l10n = context.l10n;
    await _runWithProgress('恢复中…', () async {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      final path = file?.path;
      if (path == null) return;
      final result = await service.restoreLocal(path);
      final failures = await refresher.refresh();
      final stats = result.stats;
      final additional = stats.additional.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      final summary =
          l10n.backupRestoreCounts(
            stats.books,
            stats.bookmarks,
            stats.replaceRules,
            stats.bookSources,
            stats.rssSources,
            stats.readRecords,
          ) +
          (additional == 0
              ? ''
              : '、${l10n.backupRestoreAdditional(additional)}');
      _showResult(
        result.preferencesError == null
            ? '${l10n.restoreSuccess}：$summary${result.warnings.isEmpty ? '' : '\n${result.warnings.join('\n')}'}'
            : l10n.backupRestorePreferencesFailed(
                summary,
                '${result.preferencesError}',
              ),
        failures,
      );
    });
  }

  void _showResult(String message, [List<String> failures = const []]) {
    if (!mounted) return;
    final warning = failures.isEmpty ? '' : '\n部分界面刷新失败：${failures.join('、')}';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$message$warning')));
  }

  Future<void> _showRestoreIgnore() async {
    final repository = ref.read(restoreIgnoreRepositoryProvider);
    final RestoreIgnoreConfig initial;
    try {
      initial = await repository.load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('恢复忽略项读取失败，请重试')));
      }
      return;
    }
    if (!mounted) return;
    final result = await showDialog<RestoreIgnoreConfig>(
      context: context,
      builder: (ctx) => RestoreIgnoreDialog(initial: initial),
    );
    if (result == null || !mounted) return;
    try {
      await repository.save(result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('恢复忽略项保存失败，请重试')));
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存恢复忽略项')));
  }

  Future<void> _doImportOldData() async {
    final service = ref.read(backupServiceProvider);
    final refresher = ref.read(restoredSettingsRefresherProvider);
    await _runWithProgress('导入中…', () async {
      final path = await FilePicker.getDirectoryPath(dialogTitle: '选择旧版备份目录');
      if (path == null) return;
      final message = await service.importOldData(path);
      final failures = await refresher.refresh();
      _showResult(message, failures);
    });
  }

  Future<void> _runWithProgress(
    String label,
    Future<void> Function() task,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        // [LAYOUT_PLAN P3] Dialog 容器 surfaceContainer 圆角 28dp（全局标尺，对齐 dialogTheme）
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _busy = false);
      }
    }
  }

  // ===== 测试配置（差异清单 C7：参考版有「测试配置」行，我方新增） =====

  /// 使用当前连接快照进行只读测试，不触发配置保存。— Codex + UI
  Future<void> _testWebDavConnection() async {
    if (_testStatus == _WebDavTestStatus.testing) return;
    final messenger = ScaffoldMessenger.of(context);
    final connection = ref.read(syncNotifierProvider.notifier).connection;
    if (connection.url.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('请先填写服务器地址')));
      return;
    }

    setState(() => _testStatus = _WebDavTestStatus.testing);
    try {
      final result = await ref
          .read(webDavServiceProvider)
          .webdavProbe(connection);
      if (!mounted) return;
      setState(() {
        _testStatus = result.status == WebDavProbeStatus.success
            ? _WebDavTestStatus.success
            : _WebDavTestStatus.failed;
      });
      final message = switch (result.status) {
        WebDavProbeStatus.success => '连接成功',
        WebDavProbeStatus.authenticationFailed => '认证失败，请检查账号/密码',
        WebDavProbeStatus.httpFailed => '连接失败（HTTP ${result.statusCode}）',
        WebDavProbeStatus.timedOut => '连接超时（5 秒内未响应）',
        WebDavProbeStatus.networkFailed => '连接失败，请检查网络、服务器地址或证书',
        WebDavProbeStatus.invalidUrl => '服务器地址无效，请填写完整的 http(s):// 地址',
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _testStatus = _WebDavTestStatus.failed);
      messenger.showSnackBar(const SnackBar(content: Text('连接测试失败，请重试')));
    }
  }

  /// 「测试配置」行尾状态标签
  ///
  /// 颜色：成功=主题 primary、失败=主题 error、其余=正文色
  Widget _buildTestStatusLabel() {
    final theme = Theme.of(context);
    final (label, color) = switch (_testStatus) {
      _WebDavTestStatus.notTested => ('未测试', null),
      _WebDavTestStatus.testing => (context.l10n.backupTesting, null),
      _WebDavTestStatus.success => ('✓ 连接成功', theme.colorScheme.primary),
      _WebDavTestStatus.failed => ('✗ 失败', theme.colorScheme.error),
    };
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(color: color),
    );
  }

  void _showHelp() {
    showHelp(context, HelpAssets.webDavHelp);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(backupSettingsProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final notifier = ref.read(syncNotifierProvider.notifier);

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: Text(context.l10n.backupAndRestore),
        actions: [
          IconButton(
            icon: const Icon(Symbols.help_rounded),
            tooltip: context.l10n.help,
            onPressed: _showHelp,
          ),
          AppMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'import_old':
                  _doImportOldData();
                case 'log':
                  GoRouter.of(context).pushAppRoute(AppRoutes.appLog);
              }
            },
            itemBuilder: (ctx) => [
              AppMenuItem(
                value: 'import_old',
                child: Text(ctx.l10n.backupMenuImportOldVersion),
              ),
              AppMenuItem(value: 'log', child: Text(ctx.l10n.logs)),
            ],
          ),
        ],
      ),
      body: SettingsBody(
        // [LAYOUT_PLAN P3] 列表边距 16dp 走 SettingsBody（全局标尺）
        child: ListView(
          // [LAYOUT_PLAN P3] 底部 bottom32 保留
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SettingsGroup(
              title: context.l10n.webdavSettings,
              children: [
                SettingTile(
                  title: context.l10n.webdavServerAddress,
                  subtitle: _url.isEmpty
                      ? context.l10n.webdavServerAddressHint
                      : _url,
                  onTap: _savingConnection
                      ? null
                      : () => _editTextPref(
                          title: context.l10n.webdavServerAddress,
                          initial: _url,
                          hint: 'https://dav.example.com/',
                          onSaved: (v) => _saveWebDav(url: v),
                        ),
                ),
                SettingTile(
                  title: context.l10n.webdavAccount,
                  subtitle: _user.isEmpty
                      ? context.l10n.webdavAccountHint
                      : _user,
                  onTap: _savingConnection
                      ? null
                      : () => _editTextPref(
                          title: context.l10n.webdavAccount,
                          initial: _user,
                          onSaved: (v) => _saveWebDav(username: v),
                        ),
                ),
                SettingTile(
                  title: context.l10n.webdavPassword,
                  subtitle: _pass.isEmpty
                      ? context.l10n.webdavPasswordHint
                      : '*' * _pass.length,
                  onTap: _savingConnection
                      ? null
                      : () => _editTextPref(
                          title: context.l10n.webdavPassword,
                          initial: _pass,
                          obscure: true,
                          onSaved: (v) => _saveWebDav(password: v),
                        ),
                ),
                SettingTile(
                  title: '子目录',
                  subtitle: _dir.isEmpty ? 'legado' : _dir,
                  onTap: _savingConnection
                      ? null
                      : () => _editTextPref(
                          title: '子目录',
                          initial: _dir,
                          hint: 'legado',
                          onSaved: (v) => _saveWebDav(remoteDir: v),
                        ),
                ),
                SettingTile(
                  title: context.l10n.backupWebdavDeviceName,
                  subtitle: _pendingDescription(
                    _device.isEmpty ? '用于区分不同设备的备份' : _device,
                  ),
                  onTap: null,
                  enabled: false,
                ),
                // 差异清单 C7：参考版有「测试配置」行 → 连通性+认证探测（只读服务）
                SettingTile(
                  title: context.l10n.webdavTestConfig,
                  subtitle: '连接测试服务器地址与账号',
                  trailing: _buildTestStatusLabel(),
                  // 测试期间禁用防重入
                  onTap: _testStatus == _WebDavTestStatus.testing
                      ? null
                      : _testWebDavConnection,
                ),
                SettingSwitchRow(
                  title: context.l10n.webdavSyncProgress,
                  subtitle: '在多设备间同步书籍阅读进度',
                  value: syncState.syncBookProgress,
                  onChanged: (v) => _saveBackupPreference(
                    () => notifier.setSyncBookProgress(v),
                  ),
                ),
                SettingSwitchRow(
                  title: '同步书籍进度增强',
                  subtitle: _pendingDescription('同步更详细的阅读进度信息'),
                  value: syncState.syncBookProgressPlus,
                  onChanged: null,
                ),
              ],
            ),

            const SizedBox(height: 16),
            SettingsGroup(
              title: context.l10n.backupAndRestore,
              children: [
                SettingTile(
                  title: context.l10n.backupPath,
                  subtitle: _backupPath.isEmpty
                      ? context.l10n.backupSelectBackupPath
                      : _backupPath,
                  onTap: _busy ? null : _pickBackupPath,
                ),
                SettingTile(
                  title: context.l10n.backupLocalPassword,
                  subtitle: _hasBackupPassword
                      ? context.l10n.backupPasswordSet
                      : context.l10n.backupPasswordNotSet,
                  onTap: _busy ? null : _editBackupPassword,
                ),
                SettingSwitchRow(
                  title: context.l10n.backupCloudCredentials,
                  subtitle: context.l10n.backupCloudCredentialsDescription,
                  value: ref
                      .read(backupSettingsRepositoryProvider)
                      .current
                      .includeCloudCredentials,
                  onChanged: _busy
                      ? null
                      : (value) => _saveBackupPreference(
                          () => ref
                              .read(backupSettingsRepositoryProvider)
                              .update(includeCloudCredentials: value),
                        ),
                ),
                SettingTile(
                  title: context.l10n.backup,
                  subtitle: context.l10n.backupSummary,
                  onTap: _busy ? null : _doLocalBackup,
                ),
                // 短按 WebDAV 优先；长按本地恢复
                GestureDetector(
                  onLongPress: _busy ? null : _doRestoreFromLocal,
                  child: SettingTile(
                    title: context.l10n.restore,
                    subtitle: '优先从 WebDav 恢复，长按从本地恢复',
                    onTap: _busy ? null : _doRestore,
                  ),
                ),
                SettingTile(
                  title: context.l10n.backupRestoreIgnore,
                  subtitle: '恢复时忽略一些内容不恢复，方便不同手机配置不同',
                  onTap: _busy ? null : _showRestoreIgnore,
                ),
                SettingSwitchRow(
                  title: context.l10n.backupKeepLatest,
                  subtitle: _pendingDescription(
                    context.l10n.backupKeepLatestDescription,
                  ),
                  value: _onlyLatestBackup,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: context.l10n.backupCheckNew,
                  subtitle: _pendingDescription(
                    context.l10n.backupCheckNewDescription,
                  ),
                  value: _autoCheckNewBackup,
                  onChanged: null,
                ),
              ],
            ),
            if (syncState.lastSyncTimeLabel.isNotEmpty)
              SettingsSectionFooter('上次同步：${syncState.lastSyncTimeLabel}'),
            if (syncState.status == SyncStatus.success &&
                syncState.error != null)
              SettingsSectionFooter(syncState.error!),
          ],
        ),
      ),
    );
  }
}
