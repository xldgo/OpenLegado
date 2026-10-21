import '../application/app_services_controller.dart';

import 'dart:async';

import '../../../app/routing/app_navigation.dart';
import '../../../providers/app_services_provider.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/legado_app_bar.dart';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../l10n/app_localization.dart';
import '../../../app/routing/route_names.dart';
import '../../../utils/error_message.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/app_bottom_bar_inset.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/help/help_assets.dart';
import '../../../widgets/help/show_help.dart';
import '../../reader/presentation/overlays/reader_settings_sheet.dart';

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

  late final AppServicesController _services;
  bool get _autoTaskService => _services.state.autoTask;
  bool get _webService => _services.state.web;
  bool get _mcpService => _services.state.mcp;
  bool get _webServiceBusy => _services.state.webBusy;
  bool get _mcpServiceBusy => _services.state.mcpBusy;
  bool get _webKeepAliveUnavailable => _services.state.keepAliveUnavailable;
  int get _mcpPort => _services.state.mcpPort;
  bool get _mcpTokenConfigured => _services.state.tokenConfigured;
  String get _webServiceStatus {
    final error =
        _services.state.webError ?? _services.state.webStatusReadError;
    if (error != null) {
      return context.l10n.webServiceStatusFailed(errorMessage(error));
    }
    final status = _services.state.webStatus;
    if (status == null) return context.l10n.webServiceChecking;
    return status.running
        ? context.l10n.webServiceRunning(status.port)
        : context.l10n.webServiceSummary;
  }

  void _onServicesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _services = ref.read(appServicesControllerProvider);
    _services.addListener(_onServicesChanged);
    unawaited(_services.load());
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

  @override
  void dispose() {
    _services.removeListener(_onServicesChanged);
    super.dispose();
  }

  Future<void> _toggleWebService(bool enabled) async {
    try {
      await _services.setWeb(enabled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.webServiceToggleFailed(errorMessage(error)),
            ),
          ),
        );
      }
    }
  }

  /// MCP 卡片副题：运行中显示端口；未运行且未配置访问令牌时给出前置条件
  /// 提示（见 [_mcpTokenConfigured]）——「需先配置什么」直接写在卡片上，
  /// 避免点击开关失败后才得知缺少配置。
  String get _mcpServiceSubtitle {
    if (_mcpService && _mcpPort > 0) {
      return context.l10n.mcpServicePort(_mcpPort);
    }
    if (!_mcpTokenConfigured) {
      return context.l10n.mcpTokenRequired;
    }
    return context.l10n.mcpServiceSummary;
  }

  Future<void> _toggleMcpService(bool enabled) async {
    try {
      await _services.setMcp(enabled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.mcpServiceToggleFailed(errorMessage(error)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleAutoTaskService(bool enabled) =>
      _services.setAutoTask(enabled);

  /// 服务运行状态与后台保活提示；呈现统一使用设置开关行。
  String get _webServiceSubtitle {
    final baseSubtitle = _webServiceStatus;
    return _webService && _webKeepAliveUnavailable
        ? context.l10n.webKeepAliveUnavailable(baseSubtitle)
        : baseSubtitle;
  }

  @override
  Widget build(BuildContext context) {
    // 展开和折叠标题分别继承主题字阶，布局由共用页壳协调。— Codex + UI
    return AppScaffold(
      topBar: LegadoAppBar(
        showBack: false,
        title: Text(context.l10n.my),
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
          padding: AppBottomBarInset.padding(
            context,
            const EdgeInsets.only(bottom: 32),
          ),
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
                          GoRouter.of(context).pushAppRoute(AppRoutes.sources),
                    ),
                    SettingTile(
                      icon: Symbols.rss_feed_rounded,
                      title: context.l10n.rssSourceManagement,
                      subtitle: context.l10n.rssSourceManagementSummary,
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.rssSourceManage),
                    ),
                    SettingTile(
                      icon: Symbols.toc_rounded,
                      title: context.l10n.txtTocRules,
                      subtitle: context.l10n.txtTocRulesSummary,
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.txtTocRules),
                    ),
                    SettingTile(
                      icon: Symbols.find_replace_rounded,
                      title: context.l10n.replaceRules,
                      subtitle: context.l10n.replaceRulesSummary,
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.replaceRules),
                    ),
                    SettingTile(
                      icon: Symbols.translate_rounded,
                      title: context.l10n.dictionaryLookup,
                      subtitle: context.l10n.dictionaryLookupSummary,
                      onTap: () =>
                          GoRouter.of(context).pushAppRoute(AppRoutes.dict),
                    ),
                    SettingTile(
                      icon: Symbols.manage_search_rounded,
                      title: context.l10n.dictionaryRules,
                      subtitle: context.l10n.dictionaryRulesSummary,
                      onTap: () =>
                          GoRouter.of(context).pushAppRoute(AppRoutes.dictRule),
                    ),
                    SettingTile(
                      icon: Icons.sell_rounded,
                      title: context.l10n.highlightRules,
                      subtitle: context.l10n.highlightRulesSummary,
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.highlightRules),
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
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.themeConfig),
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
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.readAloudSettings),
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
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.webdavSettings),
                    ),
                    SettingTile(
                      icon: Symbols.download_rounded,
                      title: context.l10n.cacheManagement,
                      subtitle: context.l10n.cacheManagementSummary,
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.offlineCache),
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
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.autoTasks),
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
                          GoRouter.of(context).pushAppRoute(AppRoutes.privacy),
                    ),
                    SettingTile(
                      icon: Symbols.tune_rounded,
                      title: context.l10n.advanced,
                      subtitle: context.l10n.advancedSummary,
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.otherSettings),
                    ),
                    SettingTile(
                      icon: Symbols.downloading_rounded,
                      title: context.l10n.downloadAndCache,
                      subtitle: context.l10n.downloadAndCacheSummary,
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.downloadCacheSettings),
                    ),
                    SettingTile(
                      icon: Symbols.bookmark_rounded,
                      title: context.l10n.bookmarks,
                      subtitle: context.l10n.allBookmarks,
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.bookmarks),
                    ),
                    SettingTile(
                      icon: Symbols.history_rounded,
                      title: context.l10n.readingRecords,
                      subtitle: context.l10n.readingRecordsSummary,
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.readRecord),
                    ),
                    SettingTile(
                      icon: Symbols.folder_rounded,
                      title: context.l10n.fileManagement,
                      subtitle: context.l10n.fileManagementSummary,
                      onTap: () =>
                          GoRouter.of(context)
                              .pushAppRoute(AppRoutes.fileManage),
                    ),
                    SettingTile(
                      icon: Symbols.info_rounded,
                      title: context.l10n.aboutSettings,
                      onTap: () =>
                          GoRouter.of(context).pushAppRoute(AppRoutes.about),
                    ),
                    if (defaultTargetPlatform != TargetPlatform.iOS)
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
