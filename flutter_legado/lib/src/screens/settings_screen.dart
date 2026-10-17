import '../providers/config_settings_provider.dart';
import '../providers/domain_config_provider.dart';
import '../providers/local_server_provider.dart';
import '../domain/models/local_server_status.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../widgets/legado_app_bar.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../l10n/app_localization.dart';
import '../routes.dart';
import '../providers/general_settings_provider.dart';
import '../utils/error_message.dart';
import '../services/auto_task_scheduler.dart';
import '../services/web_keep_alive_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/help/help_assets.dart';
import '../widgets/help/show_help.dart';
import '../features/reader/presentation/overlays/reader_settings_sheet.dart';

/// 我的页面（枢纽菜单）
///
/// 内容与规则、外观、同步与服务、定时任务及其他按职责分组。
/// 外观保留主题模式配置，本页仅提供对应入口。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.openSettingsRequest = 0});

  /// 首页齿轮每次点击时递增，定位到本页其他分组。
  final int openSettingsRequest;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final GlobalKey _otherSectionKey = GlobalKey();

  // 服务开关（对标 pref_main SwitchPreference）
  bool _autoTaskService = false;
  bool _webService = false;
  bool _mcpService = false;
  bool _webServiceBusy = false;
  bool _mcpServiceBusy = false;

  /// iOS 后台保活不可用（start 失败回退「仅前台可用」时，卡片副题提示）
  bool _webKeepAliveUnavailable = false;
  String _webServiceStatus = '';

  String _describeServerStatus(LocalServerStatus status) =>
      status.running ? 'running on port ${status.port}' : 'stopped';
  int _mcpPort = 0;

  /// Web 书源访问令牌（config:jsSourceApiToken）是否已配置。
  ///
  /// [2026-10-06 iOS 实测修复] MCP 独立服务的 Rust 启动守卫要求该配置非空
  /// （`mcp_start_internal`，rust/legado-ffi/src/api/server_api.rs），未配置时
  /// 开关必然失败——卡片副题提前给出「需先配置」提示，用户不必先点开关
  /// 撞错误。默认 true（乐观值）：配置读取完成前不误报「未配置」。
  bool _mcpTokenConfigured = true;

  /// 端口越界兜底日志只记一次（防手改 prefs 反复刷日志）
  bool _webPortFallbackLogged = false;

  @override
  void initState() {
    super.initState();
    _initServiceStates();
    if (widget.openSettingsRequest > 0) _revealOther();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openSettingsRequest != oldWidget.openSettingsRequest) {
      _revealOther();
    }
  }

  void _revealOther() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sectionContext = _otherSectionKey.currentContext;
      if (sectionContext == null) return;
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// 恢复服务开关持久化状态（config 键 webService / autoTaskService / mcpPort）
  ///
  /// [iOS 特性 | 2026-10-07 保活批核实] `webService=true` 只是 UI 镜像态
  /// （对齐原版：原版无开机/启动自拉起，见调研报告 §二.4）：App 进程重启后
  /// 进程内 Rust server 并不存在，此处也**不**自动 `startServer`、**不**启动
  /// 后台保活（没有服务可保；保活生命周期严格绑定 startServer 成功）。
  Future<void> _initServiceStates() async {
    try {
      final settings = ref.read(serviceSettingsRepositoryProvider);
      await settings.reload();
      final config = settings.current;
      final mcpToken = await ref
          .read(serverAccessRepositoryProvider)
          .getToken();
      final mcpPort = config.mcpPort;
      if (!mounted) return;
      setState(() {
        _webService = config.webEnabled;
        _autoTaskService = config.autoTaskEnabled;
        _mcpPort = mcpPort;
        _mcpService = mcpPort > 0;
        _mcpTokenConfigured = (mcpToken ?? '').trim().isNotEmpty;
      });
      if (_webService) {
        final status = await ref
            .read(localServerServiceProvider)
            .getServerStatus();
        if (!mounted) return;
        setState(() => _webServiceStatus = _describeServerStatus(status));
      }
      if (_autoTaskService) {
        AutoTaskScheduler.instance.refresh();
      }
    } catch (_) {
      // 首启无配置时静默失败，保持默认关
    }
  }

  /// 读取「其他设置 → Web 服务端口」配置（PrefKeys.webPort，默认 1122）
  ///
  /// [2026-10-06 缺陷修复] 对齐原版 `WebService.kt:244`
  /// `var port = getPrefInt(PreferKey.webPort, 1122)` → `:215 HttpServer(port)`：
  /// 启动时使用用户配置端口。此前本页调 `api.startServer()` 不传端口，恒用
  /// 默认 1122，使「其他设置」中的端口配置形同虚设。
  ///
  /// 读取写法对齐 other_settings_screen.dart 既有 `getIntPref`（同键同默认值；
  /// getIntPref 内部已对异常回落默认值）。越界兜底：设置页已校验
  /// 1024~60000（other_settings_screen.dart `_showWebPortDialog`），此处仅为
  /// 防手改 prefs 绕过校验导致启动失败，越界回落 1122 并只记一次日志。
  Future<int> _readWebPort() async {
    const defaultPort = 1122;
    final port =
        (await ref.read(generalSettingsRepositoryProvider).load()).webPort;
    if (port < 1024 || port > 60000) {
      if (!_webPortFallbackLogged) {
        _webPortFallbackLogged = true;
        debugPrint('Web 服务端口配置越界（$port），回落默认 $defaultPort');
      }
      return defaultPort;
    }
    return port;
  }

  /// Web 服务开关（对标原版 pref_main SwitchPreference）
  ///
  /// [iOS Web 服务后台保活 | 2026-10-07 用户批准方案 C+A] iOS 无前台服务，
  /// 平台等价物是 `UIBackgroundModes: audio` + 近静音音频会话（对应原版
  /// WakeLock 的「防睡眠」目的，见 docs/WEB_SERVICE_KEEPALIVE_SURVEY_20261007.md）：
  /// 启动成功后接[WebKeepAliveService.start]，停止成功后接 stop，让 App
  /// 退后台/锁屏时局域网浏览器仍可访问。保活启动失败仅记日志并回退
  /// 「仅前台可用」（卡片副题提示），不阻断服务开关。
  ///
  /// Android 侧本仓库虽有前台服务机制（platform_channel），但 Web 服务当前
  /// 未接入保活：`webServiceWakeLock` 偏好仅持久化未接线，既有前台服务仅用于
  /// 视频/听书播放（VideoPlayService / PlaybackForegroundService），故 Android
  /// 后台存活同样不作保证（如实登记，未夸大；本批按红线不动 Android）。
  Future<void> _toggleWebService(bool v) async {
    if (_webServiceBusy) return;
    setState(() => _webServiceBusy = true);
    final server = ref.read(localServerServiceProvider);
    try {
      if (v) {
        // 启动端口取用户配置（PrefKeys.webPort），越界按 1122 兜底
        final port = await _readWebPort();
        await server.startServer(port: port);
        final status = await server.getServerStatus();
        // 服务成功即接保活（iOS 专用；其它平台 no-op）
        final keepAlive = await WebKeepAliveService.instance.start();
        await ref
            .read(serviceSettingsRepositoryProvider)
            .update((s) => s.copyWith(webEnabled: true));
        if (!mounted) return;
        setState(() {
          _webService = true;
          _webServiceStatus = _describeServerStatus(status);
          _webKeepAliveUnavailable = keepAlive == WebKeepAliveStatus.failed;
        });
      } else {
        await server.stopServer();
        // 服务停止必须同步停保活（否则静音音轨会让进程继续存活）
        await WebKeepAliveService.instance.stop();
        await ref
            .read(serviceSettingsRepositoryProvider)
            .update((s) => s.copyWith(webEnabled: false));
        if (!mounted) return;
        setState(() {
          _webService = false;
          _webServiceStatus = '';
          _webKeepAliveUnavailable = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // [2026-10-06 iOS 实测修复] 裸插值 $e 对 Rust BridgeError 只会显示
      // "Instance of 'BridgeError'"，改用统一提取器暴露 Rust 侧可读原因
      // （如「数据库未初始化」「端口绑定失败」）。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.webServiceToggleFailed(errorMessage(e))),
        ),
      );
    } finally {
      if (mounted) setState(() => _webServiceBusy = false);
    }
  }

  /// MCP 卡片副题：运行中显示端口；未运行且未配置访问令牌时给出前置条件
  /// 提示（见 [_mcpTokenConfigured]）——「需先配置什么」直接写在卡片上，
  /// 而不是让用户点开关撞「Instance of BridgeError」后再猜。
  String get _mcpServiceSubtitle {
    if (_mcpService && _mcpPort > 0) {
      return context.l10n.mcpServicePort(_mcpPort);
    }
    if (!_mcpTokenConfigured) {
      return context.l10n.mcpTokenRequired;
    }
    return context.l10n.mcpServiceSummary;
  }

  Future<void> _toggleMcpService(bool v) async {
    if (_mcpServiceBusy) return;
    setState(() => _mcpServiceBusy = true);
    final server = ref.read(localServerServiceProvider);
    try {
      if (v) {
        final port = _mcpPort > 0 ? _mcpPort : 1236;
        await server.setMcpPort(port);
        await ref.read(serviceSettingsRepositoryProvider).reload();
        if (!mounted) return;
        setState(() {
          _mcpService = true;
          _mcpPort = port;
        });
      } else {
        await server.setMcpPort(0);
        await ref.read(serviceSettingsRepositoryProvider).reload();
        if (!mounted) return;
        setState(() {
          _mcpService = false;
          _mcpPort = 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // [2026-10-06 iOS 实测修复] 同 Web 开关：BridgeError 取 message，
      // 暴露 Rust 侧真实失败原因（token 未配置 / 端口占用 / 端口越界）。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.mcpServiceToggleFailed(errorMessage(e))),
        ),
      );
    } finally {
      if (mounted) setState(() => _mcpServiceBusy = false);
    }
  }

  Future<void> _toggleAutoTaskService(bool v) async {
    setState(() => _autoTaskService = v);
    try {
      await ref
          .read(serviceSettingsRepositoryProvider)
          .update((s) => s.copyWith(autoTaskEnabled: v));
    } catch (_) {
      // 持久化失败不阻断 UI 切换
    }
    if (v) {
      AutoTaskScheduler.instance.refresh();
    } else {
      AutoTaskScheduler.instance.cancelAll();
    }
  }

  /// 服务运行状态与后台保活提示；呈现统一使用设置开关行。
  String get _webServiceSubtitle {
    final baseSubtitle = _webService && _webServiceStatus.isNotEmpty
        ? _webServiceStatus
        : context.l10n.webServiceSummary;
    return _webService && _webKeepAliveUnavailable
        ? context.l10n.webKeepAliveUnavailable(baseSubtitle)
        : baseSubtitle;
  }

  @override
  Widget build(BuildContext context) {
    // 主页面标题与操作按钮同排，列表从工具栏下方开始。
    return AppScaffold(
      topBar: LegadoAppBar(
        showBack: false,
        title: Text(
          context.l10n.my,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontSize: 28),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.help_rounded),
            tooltip: context.l10n.help,
            onPressed: _showHelp,
          ),
        ],
      ),
      body: SettingsBody(
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          children: [
            // 分组整体构建，确保首页快捷入口能定位尚未滚动到的其他区域。
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  title: context.l10n.contentAndRules,
                  children: [
                    SettingTile(
                      icon: Symbols.library_books_rounded,
                      title: context.l10n.sourceManagement,
                      subtitle: context.l10n.sourceManagementSummary,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.sources),
                    ),
                    SettingTile(
                      icon: Symbols.rss_feed_rounded,
                      title: context.l10n.rssSourceManagement,
                      subtitle: context.l10n.rssSourceManagementSummary,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.rssSourceManage,
                      ),
                    ),
                    SettingTile(
                      icon: Symbols.toc_rounded,
                      title: context.l10n.txtTocRules,
                      subtitle: context.l10n.txtTocRulesSummary,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.txtTocRules),
                    ),
                    SettingTile(
                      icon: Symbols.find_replace_rounded,
                      title: context.l10n.replaceRules,
                      subtitle: context.l10n.replaceRulesSummary,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.replaceRules),
                    ),
                    SettingTile(
                      icon: Symbols.translate_rounded,
                      title: context.l10n.dictionaryLookup,
                      subtitle: context.l10n.dictionaryLookupSummary,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.dict),
                    ),
                    SettingTile(
                      icon: Symbols.manage_search_rounded,
                      title: context.l10n.dictionaryRules,
                      subtitle: context.l10n.dictionaryRulesSummary,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.dictRule),
                    ),
                    SettingTile(
                      icon: Icons.sell_rounded,
                      title: context.l10n.highlightRules,
                      subtitle: context.l10n.highlightRulesSummary,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.highlightRules,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  title: context.l10n.appearance,
                  children: [
                    SettingTile(
                      icon: Symbols.palette_rounded,
                      title: context.l10n.appearance,
                      subtitle: context.l10n.appearanceSummary,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.themeConfig),
                    ),
                    SettingTile(
                      icon: Symbols.style_rounded,
                      title: context.l10n.readingInterface,
                      subtitle: context.l10n.readingInterfaceSummary,
                      onTap: () => ReaderSettingsSheet.showPage(context),
                    ),
                    SettingTile(
                      icon: Symbols.record_voice_over_rounded,
                      title: context.l10n.readAloudSettingsTitle,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.readAloudSettings,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  title: context.l10n.syncAndServices,
                  children: [
                    SettingSwitchRow(
                      leading: _webServiceBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Symbols.language_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      title: context.l10n.webService,
                      subtitle: _webServiceSubtitle,
                      value: _webService,
                      onChanged: _webServiceBusy ? null : _toggleWebService,
                    ),
                    SettingSwitchRow(
                      leading: _mcpServiceBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Symbols.cable_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      title: context.l10n.mcpService,
                      subtitle: _mcpServiceSubtitle,
                      value: _mcpService,
                      onChanged: _mcpServiceBusy ? null : _toggleMcpService,
                    ),
                    SettingTile(
                      icon: Symbols.backup_rounded,
                      title: context.l10n.backupAndRestore,
                      subtitle: context.l10n.backupAndRestoreSummary,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.webdavSettings,
                      ),
                    ),
                    SettingTile(
                      icon: Symbols.download_rounded,
                      title: context.l10n.cacheManagement,
                      subtitle: context.l10n.cacheManagementSummary,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.offlineCache),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  title: context.l10n.scheduledTasks,
                  children: [
                    SettingTile(
                      icon: Symbols.schedule_rounded,
                      title: context.l10n.scheduledTasks,
                      subtitle: context.l10n.scheduledTasksSummary,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.autoTasks),
                    ),
                    SettingSwitchRow(
                      icon: Symbols.autorenew_rounded,
                      title: context.l10n.runScheduledTasks,
                      subtitle: context.l10n.runScheduledTasksSummary,
                      value: _autoTaskService,
                      onChanged: _toggleAutoTaskService,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  key: _otherSectionKey,
                  title: context.l10n.otherSettings,
                  children: [
                    SettingTile(
                      icon: Symbols.lock_rounded,
                      title: '隐私',
                      subtitle: '私密内容与访问验证',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.privacy),
                    ),
                    SettingTile(
                      icon: Symbols.tune_rounded,
                      title: context.l10n.advanced,
                      subtitle: context.l10n.advancedSummary,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.otherSettings),
                    ),
                    SettingTile(
                      icon: Symbols.bookmark_rounded,
                      title: context.l10n.bookmarks,
                      subtitle: context.l10n.allBookmarks,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.bookmarks),
                    ),
                    SettingTile(
                      icon: Symbols.history_rounded,
                      title: context.l10n.readingRecords,
                      subtitle: context.l10n.readingRecordsSummary,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.readRecord),
                    ),
                    SettingTile(
                      icon: Symbols.folder_rounded,
                      title: context.l10n.fileManagement,
                      subtitle: context.l10n.fileManagementSummary,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.fileManage),
                    ),
                    SettingTile(
                      icon: Symbols.info_rounded,
                      title: context.l10n.aboutSettings,
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.about),
                    ),
                    SettingTile(
                      icon: Symbols.logout_rounded,
                      title: context.l10n.exitApp,
                      onTap: _confirmExit,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 帮助（对标 main_my.xml → showHelp("appHelp")）
  void _showHelp() {
    showHelp(context, HelpAssets.appHelp);
  }

  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.exitApp),
        content: Text(context.l10n.confirmExitApp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SystemNavigator.pop();
    }
  }
}
