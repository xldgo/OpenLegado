import '../l10n/app_localization.dart';
import '../widgets/app_menu.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../constants/pref_keys.dart';
import '../domain/models/restore_ignore_config.dart';
import '../l10n/app_strings.dart';
import '../models/book.dart';
import '../features/bookshelf/bookshelf.dart';
import '../providers/main_prefs_notifier.dart';
import '../providers/bookshelf_settings_provider.dart';
import '../providers/read_record_settings_provider.dart';
import '../providers/reader/reader_settings_provider.dart';
import '../providers/locale_settings_provider.dart';
import '../providers/eye_protection_settings_provider.dart';
import '../providers/welcome_settings_provider.dart';
import '../providers/providers.dart';
import '../providers/sync/sync_notifier.dart';
import '../providers/theme/theme_colors_notifier.dart';
import '../providers/theme/theme_notifier.dart';
import '../providers/ui_settings/ui_settings_notifier.dart';
import '../providers/theme/system_bar_notifier.dart';
import '../routes.dart';
import '../providers/backup_settings_provider.dart';
import '../providers/general_settings_provider.dart';
import '../providers/restore_ignore_provider.dart';
import '../services/restore_ignore_prefs.dart';
import '../services/settings_service.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/help/help_assets.dart';
import '../widgets/help/show_help.dart';
import '../widgets/restore_ignore_dialog.dart';

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

  Future<void> _pickBackupPath() async {
    final picked = await FilePicker.getDirectoryPath(dialogTitle: '选择备份路径');
    if (picked == null) return;
    await _saveBackupPreference(
      () =>
          ref.read(backupSettingsRepositoryProvider).update(backupPath: picked),
    );
  }

  Future<void> _doLocalBackup() async {
    await _runWithProgress('备份中…', () async {
      final ignore = await ref.read(restoreIgnoreRepositoryProvider).load();
      final api = ref.read(bookApiProvider);
      var dirPath = _backupPath;
      if (dirPath.isEmpty) {
        final picked = await FilePicker.getDirectoryPath();
        if (picked == null) return;
        dirPath = picked;
        await ref
            .read(backupSettingsRepositoryProvider)
            .update(backupPath: dirPath);
      }
      final filePath = await api.backup(dirPath);
      await RestoreIgnorePrefs.injectAppPrefsIntoBackupFile(
        filePath,
        ignore.values,
      );
      // 同步 WebDAV（对齐原版本地与 WebDav 一起备份）
      final sync = ref.read(syncNotifierProvider);
      if (sync.isConfigured) {
        try {
          await ref.read(syncNotifierProvider.notifier).backupToWebDav();
        } catch (_) {
          // WebDAV 失败不阻断本地备份成功提示
        }
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('${AppStrings.backupSuccess}：$filePath')),
      );
    });
  }

  /// 默认恢复：优先 WebDAV；失败或未配置则提示（长按走本地）
  Future<void> _doRestore() async {
    final sync = ref.read(syncNotifierProvider);
    if (sync.isConfigured) {
      await _runWithProgress('恢复中…', () async {
        final message = await ref
            .read(syncNotifierProvider.notifier)
            .restoreFromWebDav();
        if (!mounted) return;
        await _reloadPrefsAfterRestore();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.isEmpty ? '恢复完成' : message)),
        );
      });
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('未配置 WebDAV，请长按「恢复」从本地恢复')));
  }

  Future<void> _doRestoreFromLocal() async {
    await _runWithProgress('恢复中…', () async {
      final api = ref.read(bookApiProvider);
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
      );
      final backupPath = result?.path;
      if (backupPath == null) return;

      var pathToRestore = backupPath;
      final ignore = await ref.read(restoreIgnoreRepositoryProvider).load();
      if (ignore['localBook'] == true &&
          backupPath.toLowerCase().endsWith('.json')) {
        pathToRestore = await _backupPathSkippingLocalBooks(backupPath);
      }

      await RestoreIgnorePrefs.applyAppPrefsFromBackupFile(
        backupPath,
        ignore.values,
      );
      await api.restore(pathToRestore);
      if (!mounted) return;
      await _reloadPrefsAfterRestore();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppStrings.restoreSuccess)));
    });
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
    await _runWithProgress('导入中…', () async {
      final dirPath = await FilePicker.getDirectoryPath(
        dialogTitle: '选择旧版备份目录',
      );
      if (dirPath == null) return;

      final api = ref.read(bookApiProvider);
      final raw = await api.importOldData(dirPath);
      final decoded = jsonDecode(raw);
      String message;
      if (decoded is Map) {
        final msgs = decoded['messages'];
        if (msgs is List && msgs.isNotEmpty) {
          message = msgs.map((e) => '$e').join('\n');
        } else {
          final books = decoded['books'] ?? 0;
          final sources = decoded['bookSources'] ?? 0;
          final rules = decoded['replaceRules'] ?? 0;
          message = '书架 $books · 书源 $sources · 替换规则 $rules';
        }
      } else {
        message = '导入完成';
      }

      ref.read(bookshelfNotifierProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Future<void> _reloadPrefsAfterRestore() async {
    try {
      await ref.read(themeNotifierProvider.notifier).reload();
    } on AppearanceSyncException catch (error) {
      // 恢复已落盘，原生同步失败不能阻断其他界面状态的刷新。
      debugPrint('外观偏好已恢复，主题同步失败：${error.cause}');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: const Text('设置已恢复，主题同步失败')));
      }
    }
    if (!mounted) return;
    try {
      await ref.read(themeColorsProvider.notifier).reload();
    } catch (error) {
      debugPrint('主题颜色恢复后读取失败：$error');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('主题颜色读取失败，请重试')));
      }
    }
    if (!mounted) return;
    try {
      await ref.read(mainPrefsProvider.notifier).reload();
    } catch (error) {
      debugPrint('主界面偏好恢复后读取失败：$error');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('主界面设置读取失败，请重试')));
      }
    }
    if (!mounted) return;
    try {
      await ref.read(uiSettingsProvider.notifier).reload();
    } catch (error) {
      debugPrint('界面布局恢复后读取失败：$error');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('界面布局读取失败，请重试')));
      }
    }
    if (!mounted) return;
    try {
      await ref.read(systemBarProvider.notifier).reload();
    } catch (error) {
      debugPrint('系统栏偏好恢复后读取失败：$error');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('系统栏设置读取失败，请重试')));
      }
    }
    if (!mounted) return;
    final reloads = <(String, Future<void> Function())>[
      ('书架', () => ref.read(bookshelfSettingsRepositoryProvider).reload()),
      ('阅读记录', () => ref.read(readRecordSettingsRepositoryProvider).reload()),
      ('基础阅读', () => ref.read(readerSettingsRepositoryProvider).reload()),
      ('字体目录', () => ref.read(readerFontRepositoryProvider).reload()),
      ('阅读配色', () => ref.read(readerStyleRepositoryProvider).reload()),
      ('语言', () => ref.read(localeSettingsRepositoryProvider).reload()),
      ('护眼', () => ref.read(eyeProtectionSettingsRepositoryProvider).reload()),
      ('欢迎页', () => ref.read(welcomeSettingsRepositoryProvider).reload()),
      ('应用行为', () => ref.read(generalSettingsRepositoryProvider).reload()),
      ('备份', () => ref.read(backupSettingsRepositoryProvider).reload()),
    ];
    for (final (label, reload) in reloads) {
      if (!mounted) return;
      try {
        await reload();
      } catch (error) {
        debugPrint('$label 设置恢复后读取失败：$error');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$label 设置读取失败，请重试')));
        }
      }
    }
    if (!mounted) return;
    ref.invalidate(bookshelfNotifierProvider);
  }

  Future<String> _backupPathSkippingLocalBooks(String backupPath) async {
    final raw = await File(backupPath).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return backupPath;
    final books = decoded['books'];
    if (books is! List) return backupPath;

    decoded['books'] = books.where((item) {
      if (item is! Map) return true;
      final origin = item['origin']?.toString() ?? '';
      final type = item['type'];
      final typeInt = type is int ? type : int.tryParse('$type') ?? 0;
      final isLocal =
          origin == BookType.localTag ||
          origin.startsWith(BookType.webDavTag) ||
          (typeInt & BookType.local) != 0;
      return !isLocal;
    }).toList();

    final dir = Directory.systemTemp;
    final out = File(
      '${dir.path}${Platform.pathSeparator}legado_restore_no_local_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await out.writeAsString(jsonEncode(decoded));
    return out.path;
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

  /// 对当前已填写的 WebDAV 配置发起一次连通性探测（纯客户端行为，不落库）
  ///
  /// 判定：PROPFIND（Depth: 0）+ 已填账号密码 Basic Auth，5 秒超时；
  /// 200/207 → 成功；401/403 → 认证失败；其他非 2xx/异常/超时 → 失败。
  /// 测试期间该行禁用防重入；结果以 SnackBar 呈现并更新行尾状态。
  /// — full-stack-engineer + UI ｜ 2026-09-10
  Future<void> _testWebDavConnection() async {
    if (_testStatus == _WebDavTestStatus.testing) return;
    final messenger = ScaffoldMessenger.of(context);
    final url = _url.trim();
    if (url.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('请先填写服务器地址')));
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('服务器地址需要以 http(s):// 开头')),
      );
      return;
    }

    setState(() => _testStatus = _WebDavTestStatus.testing);
    final client = http.Client();
    try {
      final request = http.Request('PROPFIND', Uri.parse(url));
      // Basic Auth 使用已填账号/密码（均为空时不带 Authorization 头，避免误触发 401）
      if (_user.isNotEmpty || _pass.isNotEmpty) {
        request.headers['Authorization'] =
            'Basic '
            '${base64Encode(utf8.encode('$_user:$_pass'))}';
      }
      request.headers['Depth'] = '0';
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 5));
      final response = await http.Response.fromStream(streamed);
      // 探测期间已离开页面则不再更新 UI（client 由 finally 关闭）
      if (!mounted) return;
      final code = response.statusCode;
      final ok = code == 200 || code == 207;
      setState(() {
        _testStatus = ok ? _WebDavTestStatus.success : _WebDavTestStatus.failed;
      });
      if (ok) {
        messenger.showSnackBar(const SnackBar(content: Text('连接成功')));
      } else if (code == 401 || code == 403) {
        messenger.showSnackBar(const SnackBar(content: Text('认证失败，请检查账号/密码')));
      } else {
        messenger.showSnackBar(SnackBar(content: Text('连接失败（HTTP $code）')));
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _testStatus = _WebDavTestStatus.failed);
      messenger.showSnackBar(const SnackBar(content: Text('连接超时（5 秒内未响应）')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _testStatus = _WebDavTestStatus.failed);
      messenger.showSnackBar(
        SnackBar(content: Text('连接失败：${_summarizeProbeError(e)}')),
      );
    } finally {
      client.close();
    }
  }

  /// 探测失败原因摘要（限 40 字符，防 SnackBar 溢出）
  String _summarizeProbeError(Object e) {
    final raw = e.toString().split('\n').first;
    return raw.length > 40 ? '${raw.substring(0, 40)}…' : raw;
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
                  Navigator.pushNamed(context, AppRoutes.appLog);
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
          padding: const EdgeInsets.only(top: 16, bottom: 32),
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
                // 差异清单 C7：参考版有「测试配置」行 → 连通性+认证探测（纯客户端）
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
