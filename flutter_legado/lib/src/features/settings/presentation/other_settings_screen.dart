import '../../../utils/error_message.dart';
import '../../../providers/domain_config_provider.dart';
import '../../../providers/config_settings_provider.dart'
    show serviceSettingsRepositoryProvider;
import '../../../providers/local_server_provider.dart';
import '../../../providers/network_provider.dart';

// 其他设置保留通用偏好、平台服务和书源辅助配置。
// 下载并发、图片缓存、User-Agent与维护操作已迁到独立下载与缓存页。
// 未接线项只读展示，已接线项沿用现有窄接口。— Codex + UI
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../constants/pref_keys.dart';
import '../../../l10n/app_localization.dart';
import '../../../providers/app_locale_notifier.dart';
import '../../../providers/welcome_settings_provider.dart';
import '../../../providers/general_settings_provider.dart';
import '../../home/application/main_prefs_notifier.dart';
import '../../../providers/providers.dart';
import '../../book_sources/application/source_check/check_source_notifier.dart';
import '../../../services/crash_log_service.dart';
import '../../../services/settings_service.dart';
import '../../../widgets/settings_widgets.dart';
import '../../../widgets/video_settings_dialog.dart';

/// 其他设置页面（对齐原版 OtherConfigFragment）
///
/// 保留语言、主界面和其他偏好；下载与缓存配置已迁到独立页面。
/// 已移除原版不存在的「默认阅读设置 / 网络设置」创意分组。
/// Cronet / 直链上传规则：F4-5 按 RESIDUAL「不做」销记，不展示空壳控件。
class OtherSettingsScreen extends ConsumerStatefulWidget {
  const OtherSettingsScreen({super.key});

  @override
  ConsumerState<OtherSettingsScreen> createState() =>
      _OtherSettingsScreenState();
}

class _OtherSettingsScreenState extends ConsumerState<OtherSettingsScreen> {
  SettingsService get _settingsService => ref.read(settingsProvider);
  String get _localeValue => ref.read(appLocaleProvider);

  // ===== 主界面分组（对齐原版 auto_refresh 等键）=====
  bool _autoRefresh = false;
  bool _onlyUpdateRead = false;
  bool get _defaultToRead =>
      ref.read(welcomeSettingsRepositoryProvider).current.defaultToRead;

  // ===== 其他分组 =====
  String _localPassword = '';
  bool _webServiceWakeLock = false;
  String get _defaultBookTreeUri =>
      ref.read(generalSettingsRepositoryProvider).current.defaultBookTreeUri;
  int _sourceEditMaxLine = 99;
  bool _antiAlias = false;
  bool _replaceEnableDefault = true;
  bool _mediaButtonOnExit = true;
  bool _readAloudByMediaButton = false;
  bool _ignoreAudioFocus = false;
  bool _autoClearExpired = true;
  bool get _showAddToShelfAlert =>
      ref.read(generalSettingsRepositoryProvider).current.showAddToShelfAlert;
  bool _autoUpdateVariant = true;
  bool _showMangaUi = true;
  String _jsSourceApiToken = '';
  int get _webPort =>
      ref.read(generalSettingsRepositoryProvider).current.webPort;
  bool _processText = true;
  bool _recordLog = false;
  bool _recordHttpLog = false;
  bool _recordHeapDump = false;

  /// 自定义 hosts 当前配置 JSON（Rust 持久化 config:customHosts 回读；
  /// 空串=未配置；Task #74 §5.13-1）
  String _customHostsJson = '';

  /// 独立 MCP 服务端口（Rust 持久化 config:mcpPort 回读；
  /// ≤0=停止/未配置，默认 1236 对齐原版；Task #74 §5.13-6）
  int _mcpPort = 0;

  /// 校验书源配置（经 CheckSourceNotifier 持久化，字段对齐契约 §2.3
  /// CheckerConfig；Task #40 §5.13-2）
  Map<String, dynamic> _checkSourceConfig = {};

  /// Android 专属项统一灰字标注（与阅读设置面板刘海项先例一致）
  static const _androidOnly = '仅 Android 生效';
  static String _pendingDescription(String description) => '$description\n待实现';

  @override
  void initState() {
    super.initState();
    _loadOtherSettings();
  }

  /// 加载原版对齐新增项（键名对齐 PreferKey）
  Future<void> _loadOtherSettings() async {
    final s = _settingsService;
    try {
      await ref.read(generalSettingsRepositoryProvider).load();
    } catch (error) {
      _toast('应用设置读取失败，请重试');
    }
    _autoRefresh = await s.getBoolPref(
      PrefKeys.autoRefreshBook,
      defaultValue: false,
    );
    _onlyUpdateRead = await s.getBoolPref(
      PrefKeys.onlyUpdateRead,
      defaultValue: false,
    );
    _localPassword = await s.getStringPref(PrefKeys.localPassword);
    _webServiceWakeLock = await s.getBoolPref(
      PrefKeys.webServiceWakeLock,
      defaultValue: false,
    );
    _sourceEditMaxLine = await s.getIntPref(
      PrefKeys.sourceEditMaxLine,
      defaultValue: 99,
    );
    _antiAlias = await s.getBoolPref(PrefKeys.antiAlias, defaultValue: false);
    _replaceEnableDefault = await s.getBoolPref(
      PrefKeys.replaceEnableDefault,
      defaultValue: true,
    );
    _mediaButtonOnExit = await s.getBoolPref(
      PrefKeys.mediaButtonOnExit,
      defaultValue: true,
    );
    _readAloudByMediaButton = await s.getBoolPref(
      PrefKeys.readAloudByMediaButton,
      defaultValue: false,
    );
    _ignoreAudioFocus = await s.getBoolPref(
      PrefKeys.ignoreAudioFocus,
      defaultValue: false,
    );
    _autoClearExpired = await s.getBoolPref(
      PrefKeys.autoClearExpired,
      defaultValue: true,
    );
    _autoUpdateVariant = await s.getBoolPref(
      PrefKeys.autoUpdateVariant,
      defaultValue: true,
    );
    _showMangaUi = await s.getBoolPref(
      PrefKeys.showMangaUi,
      defaultValue: true,
    );
    _processText = await s.getBoolPref(
      PrefKeys.processText,
      defaultValue: true,
    );
    // 日志开关保留原值展示，记录路径尚未接入这些开关。
    _recordLog = await CrashLogService.instance.getRecordLog();
    _recordHttpLog = await CrashLogService.instance.getRecordHttpLog();
    _recordHeapDump = await CrashLogService.instance.getRecordHeapDump();
    // [Task #40 | 2026-08-09] §5.13-2：校验书源配置（含默认值回落） — Qoder
    _checkSourceConfig = await ref
        .read(checkSourceNotifierProvider.notifier)
        .loadCheckConfig();
    // [Task #74 | 2026-08-10] §5.13-1/§5.13-6：customHosts/mcpPort 回读——
    // Rust 侧持久化于 caches 表 config:customHosts / config:mcpPort，
    // 经既有 ConfigRepository 回读（最小改动，无需 SP 镜像） — Qoder
    try {
      final repository = ref.read(serviceSettingsRepositoryProvider);
      await repository.reload();
      final settings = repository.current;
      _customHostsJson = settings.customHosts;
      _mcpPort = settings.mcpPort;
      _jsSourceApiToken =
          await ref.read(serverAccessRepositoryProvider).getToken() ?? '';
    } catch (e) {
      debugPrint('OtherSettingsScreen 回读 customHosts/mcpPort 异常: $e');
    }
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLocaleProvider);
    ref.watch(welcomeSettingsProvider);
    ref.watch(generalSettingsProvider);
    final mainPrefs = ref.watch(mainPrefsProvider);
    final mainPrefsNotifier = ref.read(mainPrefsProvider.notifier);

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(title: Text(context.l10n.advanced)),
      body: SettingsBody(
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          children: [
            // ===== 语言（对齐原版 language，无独立 category）=====
            SettingsGroup(
              children: [
                SettingTile(
                  icon: Symbols.language_rounded,
                  title: context.l10n.language,
                  value: _localeLabel,
                  onTap: () => _showLocalePicker(context),
                ),
              ],
            ),

            // ===== 主界面 =====
            const SizedBox(height: 16),
            SettingsGroup(
              title: context.l10n.advancedMainScreen,
              children: [
                SettingSwitchRow(
                  title: context.l10n.advancedAutoRefresh,
                  subtitle: _pendingDescription(
                    context.l10n.advancedAutoRefreshDescription,
                  ),
                  value: _autoRefresh,
                  onChanged: null,
                ),
                if (_autoRefresh)
                  SettingSwitchRow(
                    title: '仅更新已读完',
                    subtitle: _pendingDescription('自动刷新时，只更新已读完的书籍'),
                    value: _onlyUpdateRead,
                    onChanged: null,
                  ),
                SettingSwitchRow(
                  title: context.l10n.advancedRecentReading,
                  subtitle: context.l10n.advancedRecentReadingDescription,
                  value: _defaultToRead,
                  onChanged: (v) => _saveMainPreferences(
                    () => ref
                        .read(welcomeSettingsRepositoryProvider)
                        .update(defaultToRead: v),
                  ),
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedShowDiscovery,
                  value: mainPrefs.showDiscovery,
                  onChanged: (v) => _saveMainPreferences(
                    () => mainPrefsNotifier.setShowDiscovery(v),
                  ),
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedShowRss,
                  value: mainPrefs.showRss,
                  onChanged: (v) => _saveMainPreferences(
                    () => mainPrefsNotifier.setShowRss(v),
                  ),
                ),
                SettingTile(
                  icon: Symbols.home_rounded,
                  title: context.l10n.advancedDefaultHomePage,
                  value: _homePageLabel(mainPrefs.defaultHomePage),
                  onTap: () =>
                      _showHomePagePicker(mainPrefs, mainPrefsNotifier),
                ),
              ],
            ),

            // ===== 其他（顺序严格对齐 pref_config_other.xml）=====
            const SizedBox(height: 16),
            SettingsGroup(
              title: '其他设置',
              children: [
                SettingTile(
                  title: context.l10n.advancedLocalPassword,
                  subtitle: _pendingDescription(
                    context.l10n.advancedLocalPasswordDescription,
                  ),
                  value: _localPassword.isEmpty ? '未设置' : '已设置',
                  onTap: null,
                  enabled: false,
                ),
                SettingTile(
                  title: '自定义Hosts',
                  subtitle: _customHostsSummary.isEmpty
                      ? '域名到IP的映射'
                      : _customHostsSummary,
                  onTap: _showCustomHostsDialog,
                ),
                SettingSwitchRow(
                  title: 'Web 服务唤醒锁',
                  subtitle: _pendingDescription(_androidOnly),
                  value: _webServiceWakeLock,
                  onChanged: null,
                ),
                SettingTile(
                  title: context.l10n.advancedBookSaveLocation,
                  subtitle: _defaultBookTreeUri.isEmpty
                      ? context.l10n.advancedBookSaveLocationDescription
                      : _defaultBookTreeUri,
                  onTap: _showBookTreeUriDialog,
                ),
                SettingTile(
                  title: context.l10n.advancedSourceEditorMaxLines,
                  value: '$_sourceEditMaxLine',
                  onTap: null,
                  enabled: false,
                  subtitle: '待实现',
                ),
                SettingTile(
                  title: context.l10n.advancedCheckSourceSettings,
                  subtitle: _checkSourceConfigSummary,
                  onTap: _showCheckSourceConfigDialog,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedAntiAlias,
                  subtitle: _pendingDescription(
                    context.l10n.advancedAntiAliasDescription,
                  ),
                  value: _antiAlias,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedReplaceByDefault,
                  subtitle: _pendingDescription(
                    context.l10n.advancedReplaceByDefaultDescription,
                  ),
                  value: _replaceEnableDefault,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedHeadsetAlways,
                  subtitle: _pendingDescription(
                    context.l10n.advancedHeadsetAlwaysDescription,
                  ),
                  value: _mediaButtonOnExit,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedHeadsetReadAloud,
                  subtitle: _pendingDescription(
                    context.l10n.advancedHeadsetReadAloudDescription,
                  ),
                  value: _readAloudByMediaButton,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedIgnoreAudioFocus,
                  subtitle: _pendingDescription(
                    context.l10n.advancedIgnoreAudioFocusDescription,
                  ),
                  value: _ignoreAudioFocus,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedClearExpiredSearch,
                  subtitle: _pendingDescription(
                    context.l10n.advancedClearExpiredSearchDescription,
                  ),
                  value: _autoClearExpired,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedAddToShelfPrompt,
                  subtitle: context.l10n.advancedAddToShelfPromptDescription,
                  value: _showAddToShelfAlert,
                  onChanged: (v) => _saveMainPreferences(
                    () => ref
                        .read(generalSettingsRepositoryProvider)
                        .update(showAddToShelfAlert: v),
                  ),
                ),
                SettingSwitchRow(
                  title: '自动更新',
                  subtitle: _pendingDescription('每天自动检查软件是否更新'),
                  value: _autoUpdateVariant,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedMangaViewer,
                  value: _showMangaUi,
                  onChanged: null,
                  subtitle: '待实现',
                ),
                SettingTile(
                  title: '视频设置',
                  subtitle: '自动播放、全屏播放等配置',
                  onTap: () => showVideoSettingsDialog(context),
                ),
                SettingTile(
                  title: context.l10n.advancedWebPort,
                  subtitle: '当前端口 $_webPort',
                  onTap: _showWebPortDialog,
                ),
                SettingTile(
                  title: 'MCP 端口',
                  subtitle: _mcpPort > 0 ? '当前端口 $_mcpPort' : '当前端口 0（已停止）',
                  onTap: _showMcpPortDialog,
                ),
                SettingTile(
                  title: 'Web 书源访问令牌',
                  subtitle: _jsSourceApiToken.isEmpty
                      ? 'MCP、纯 JS、书源写入、搜索和调试接口均需要'
                      : '已配置',
                  onTap: _editJsSourceApiToken,
                ),
                SettingTile(
                  title: context.l10n.advancedClearWebView,
                  subtitle: context.l10n.advancedClearWebViewDescription,
                  onTap: _clearWebViewData,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedSearchTextActions,
                  subtitle: _pendingDescription('长按文字在操作菜单中显示阅读·搜索'),
                  value: _processText,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedRecordLog,
                  subtitle: _pendingDescription(
                    context.l10n.advancedRecordDebugLog,
                  ),
                  value: _recordLog,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: '记录 HTTP 请求',
                  subtitle: _pendingDescription('在内存中保留最近 50 条已脱敏的请求与响应记录'),
                  value: _recordHttpLog,
                  onChanged: null,
                ),
                SettingSwitchRow(
                  title: context.l10n.advancedHeapDump,
                  subtitle: _pendingDescription(
                    context.l10n.advancedHeapDumpDescription,
                  ),
                  value: _recordHeapDump,
                  onChanged: null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _localeLabel {
    switch (_localeValue) {
      case 'zh':
        return context.l10n.langChinese;
      case 'en':
        return context.l10n.langEnglish;
      default:
        return context.l10n.langSystem;
    }
  }

  /// 默认首页值 → 展示文案（对齐原版 default_home_page 数组）
  /// [UI_SYNC_REFACTOR S6 | 2026-09-08] 新增首页页签后补 'home' 选项 — Qoder
  String _homePageLabel(String value) {
    switch (value) {
      case 'home':
        return context.l10n.home;
      case 'explore':
        return context.l10n.discover;
      case 'rss':
        return context.l10n.rss;
      case 'my':
        return context.l10n.my;
      default:
        return context.l10n.bookshelf;
    }
  }

  /// 默认首页选择（对齐原版 defaultHomePage ListPreference）
  Future<void> _showHomePagePicker(
    MainPrefsState prefs,
    MainPrefsNotifier notifier,
  ) async {
    const options = ['home', 'bookshelf', 'explore', 'rss', 'my'];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.l10n.advancedDefaultHomePageDialog),
        children: [
          // 用 RadioGroup 统一管理选中值（避免 groupValue/onChanged 废弃 API）
          RadioGroup<String>(
            groupValue: prefs.defaultHomePage,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final value in options)
                  RadioListTile<String>(
                    title: Text(_homePageLabel(value)),
                    value: value,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    // [UI-fix v2.0.5 | 2026-08-08] 异步对话框返回后统一补 mounted 防护，
    // 避免页面已销毁时继续 setState/持久化 — Qoder
    if (selected == null || !mounted) return;
    await _saveMainPreferences(() => notifier.setDefaultHomePage(selected));
  }

  /// 保存结果由共享仓储决定；失败回退后向用户提示，不吞掉持久化错误。
  Future<void> _saveMainPreferences(Future<void> Function() save) async {
    try {
      await save();
    } catch (error) {
      debugPrint('主界面设置保存失败：$error');
      if (mounted) _toast(context.l10n.loginSaveFailed);
    }
  }

  /// 默认书籍保存位置（对齐原版 defaultBookTreeUri 目录选择）
  Future<void> _showBookTreeUriDialog() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('默认书籍保存位置'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'select'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('选择文件夹'),
            ),
          ),
          if (_defaultBookTreeUri.isNotEmpty)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('清除'),
              ),
            ),
        ],
      ),
    );
    // 异步对话框/文件选择器返回后先检查 mounted，再 setState/持久化
    if (!mounted) return;
    if (action == 'select') {
      final dir = await FilePicker.getDirectoryPath(dialogTitle: '选择默认书籍保存位置');
      if (dir == null || !mounted) return;
      await _saveMainPreferences(
        () => ref
            .read(generalSettingsRepositoryProvider)
            .update(defaultBookTreeUri: dir),
      );
    } else if (action == 'clear') {
      await _saveMainPreferences(
        () => ref
            .read(generalSettingsRepositoryProvider)
            .update(defaultBookTreeUri: ''),
      );
    }
  }

  /// Web 服务端口设置（对齐原版 webPort 1024~60000；
  /// 经 LocalServerService.setServerPort 写入引擎配置，重启 Web 服务后生效）
  Future<void> _showWebPortDialog() async {
    final value = await _showNumberInputDialog(
      title: 'Web 服务端口',
      current: _webPort,
      min: 1024,
      max: 60000,
    );
    // 异步对话框返回后先检查 mounted，再 setState/持久化与引擎同步
    if (value == null || value == _webPort || !mounted) return;
    try {
      await ref.read(generalSettingsRepositoryProvider).update(webPort: value);
    } catch (error) {
      _toast('端口保存失败，请重试');
      return;
    }
    if (!mounted) return;
    // 行为接通：同步到 Rust 引擎配置（对齐原版 webPort 变更重启 WebService）
    try {
      await ref.read(localServerServiceProvider).setServerPort(value);
      _toast('端口已保存，重启 Web 服务后生效');
    } catch (e) {
      debugPrint('OtherSettingsScreen 设置 Web 端口异常: $e');
      _toast('端口已保存（引擎同步失败，重启应用后生效）');
    }
  }

  /// 自定义 hosts 配置摘要（副标题：已配置 N 条/未配置；
  /// Task #74 §5.13-1） — Qoder
  String get _customHostsSummary {
    final trimmed = _customHostsJson.trim();
    if (trimmed.isEmpty) return '未配置（域名 → IP 映射）';
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) return '已配置 ${decoded.length} 条';
    } catch (_) {
      // 解析失败仍显示已配置（保存路径已校验，此处仅兑底）
    }
    return '已配置';
  }

  /// MCP 服务端口设置（契约 §2.22.5，对齐原版 AppConfig.mcpPort：
  /// 默认 1236、区间 1024..65530；0/留空=停止独立服务；
  /// 端口占用等失败 Toast 可读错误）
  /// [Task #74 | 2026-08-10] — Qoder
  Future<void> _showMcpPortDialog() async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _McpPortDialog(currentPort: _mcpPort),
    );
    // Task #76 Min1：去掉同端口短路（Rust 侧幂等重启语义），
    // 保证服务异常后可用同端口重启
    if (value == null || !mounted) return;
    try {
      await ref.read(localServerServiceProvider).setMcpPort(value);
      await ref.read(serviceSettingsRepositoryProvider).reload();
      if (!mounted) return;
      setState(() => _mcpPort = value);
      _toast(value > 0 ? 'MCP 端口已保存：$value（独立服务已重启）' : '独立 MCP 服务已停止');
    } catch (e) {
      debugPrint('OtherSettingsScreen 设置 MCP 端口异常: $e');
      if (mounted) _toast('MCP 端口设置失败: ${errorMessage(e)}');
    }
  }

  /// 自定义 hosts 编辑对话框（对齐原版 OtherConfigFragment
  /// .showCustomHostsDialog：预填当前配置，合法 JSON 对象才保存、
  /// 空=清除、非法 JSON 提示不保存；契约 §2.20.3）
  /// [Task #74 | 2026-08-10] — Qoder
  Future<void> _showCustomHostsDialog() async {
    final input = await showDialog<String>(
      context: context,
      builder: (_) => _CustomHostsDialog(initialText: _customHostsJson),
    );
    if (input == null || !mounted) return;
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      // 空内容=清除映射恢复系统 DNS（契约 §2.20.3）
      try {
        await ref.read(networkServiceProvider).setCustomHosts('');
        await ref.read(serviceSettingsRepositoryProvider).reload();
        if (!mounted) return;
        setState(() => _customHostsJson = '');
        _toast('自定义 hosts 已清除');
      } catch (e) {
        debugPrint('OtherSettingsScreen 清除 customHosts 异常: $e');
        if (mounted) _toast('自定义 hosts 清除失败: ${errorMessage(e)}');
      }
      return;
    }
    // 合法 JSON 对象才保存；非法 JSON 提示不保存（对齐原版）
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      _toast('非法 JSON，未保存');
      return;
    }
    if (decoded is! Map) {
      _toast('须为 JSON 对象（域名 → IP），未保存');
      return;
    }
    try {
      await ref.read(networkServiceProvider).setCustomHosts(trimmed);
      await ref.read(serviceSettingsRepositoryProvider).reload();
      if (!mounted) return;
      setState(() => _customHostsJson = trimmed);
      _toast('自定义 hosts 已保存（${decoded.length} 条）');
    } catch (e) {
      debugPrint('OtherSettingsScreen 保存 customHosts 异常: $e');
      if (mounted) _toast('自定义 hosts 保存失败: ${errorMessage(e)}');
    }
  }

  Future<void> _editJsSourceApiToken() async {
    final ctrl = TextEditingController(text: _jsSourceApiToken);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('JS 书源 API Token'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '用于 JS 书源调用外部 API 的令牌'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(serverAccessRepositoryProvider).setToken(result);
      setState(() => _jsSourceApiToken = result);
      _toast(result.isEmpty ? '已清除 Token' : 'Token 已保存');
    } catch (e) {
      _toast('保存失败：$e');
    }
  }

  Future<void> _clearWebViewData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除 WebView 数据'),
        content: const Text('将清除 WebView Cookie。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await WebViewCookieManager().clearCookies();
      _toast('WebView Cookie 已清除');
    } catch (e) {
      _toast('清除失败：$e');
    }
  }

  /// 校验书源配置摘要（对齐原版 CheckSource.summary：超时 + 已启用校验项）
  /// [Task #40 | 2026-08-09] §5.13-2 — Qoder
  String get _checkSourceConfigSummary {
    if (_checkSourceConfig.isEmpty) return '';
    final ms =
        (_checkSourceConfig['step_timeout_ms'] as num?)?.toInt() ??
        CheckSourceNotifier.defaultStepTimeoutMs;
    final items = <String>[
      if (_checkSourceConfig['check_search'] == true) '搜索',
      if (_checkSourceConfig['check_toc'] == true) '目录',
      if (_checkSourceConfig['check_content'] == true) '正文',
    ];
    final itemText = items.isEmpty ? '未设置校验步骤' : '校验${items.join('、')}';
    return '超时 ${ms ~/ 1000}秒 · $itemText';
  }

  /// 校验书源配置对话框（对齐原版 CheckSourceConfig：搜索关键词、校验超时、
  /// 各校验步骤开关；字段映射到既有 checkSource configJson 契约 §2.3）
  ///
  /// 级联约束对齐原版：校验搜索 → 目录 → 正文 逐级依赖，
  /// 关闭上级步骤时同步关闭下级。
  /// [Task #40 | 2026-08-09] §5.13-2 — Qoder
  /// [Task #54 | 2026-08-10] 缺陷②修复：对话框提取为自持 StatefulWidget
  /// （_CheckSourceConfigDialog），controller 在 State 内创建/dispose 中释放，
  /// 确认回传值而非 controller，消除退场动画期间 dispose 引发的框架断言红屏 — Qoder
  Future<void> _showCheckSourceConfigDialog() async {
    final result = await showDialog<_CheckSourceConfigResult>(
      context: context,
      builder: (_) => _CheckSourceConfigDialog(
        initialKeyword: (_checkSourceConfig['keyword'] ?? '').toString(),
        initialSeconds:
            ((_checkSourceConfig['step_timeout_ms'] as num?)?.toInt() ??
                CheckSourceNotifier.defaultStepTimeoutMs) ~/
            1000,
        initialCheckSearch: _checkSourceConfig['check_search'] == true,
        initialCheckToc: _checkSourceConfig['check_toc'] == true,
        initialCheckContent: _checkSourceConfig['check_content'] == true,
        initialDetectCaptcha: _checkSourceConfig['detect_captcha'] == true,
        initialDetectRedirect: _checkSourceConfig['detect_redirect'] == true,
      ),
    );
    // 异步对话框返回后先检查 mounted，再 setState/持久化
    if (result == null || !mounted) return;
    // 字段映射到契约 §2.3 CheckerConfig（step_timeout_ms 以毫秒传递）
    final config = <String, dynamic>{
      'keyword': result.keyword,
      'step_timeout_ms': result.seconds * 1000,
      'check_search': result.checkSearch,
      'check_toc': result.checkToc,
      'check_content': result.checkContent,
      'detect_captcha': result.detectCaptcha,
      'detect_redirect': result.detectRedirect,
    };
    await ref
        .read(checkSourceNotifierProvider.notifier)
        .saveCheckConfig(config);
    if (!mounted) return;
    setState(() => _checkSourceConfig = config);
    _toast('配置已保存，下次校验时生效');
  }

  /// 通用数字输入对话框（返回 null 表示取消）
  Future<int?> _showNumberInputDialog({
    required String title,
    required int current,
    required int min,
    required int max,
  }) async {
    final controller = TextEditingController(text: '$current');
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '$min ~ $max'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed < min || parsed > max) {
                _toast('请输入 $min ~ $max 之间的数字');
                return;
              }
              Navigator.pop(ctx, parsed);
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showLocalePicker(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.l10n.language),
        children: [
          _buildLocaleOption(ctx, 'system', context.l10n.langSystem),
          _buildLocaleOption(ctx, 'zh', context.l10n.langChinese),
          _buildLocaleOption(ctx, 'en', context.l10n.langEnglish),
        ],
      ),
    ).then((selectedLocale) async {
      // 进入 .then 回调后第一时间检查 mounted，再 setState/持久化
      if (selectedLocale == null || !mounted) return;
      await _saveMainPreferences(
        () => ref.read(appLocaleProvider.notifier).setLocale(selectedLocale),
      );
    });
  }

  Widget _buildLocaleOption(BuildContext ctx, String value, String label) {
    final isSelected = value == _localeValue;
    return ListTile(
      leading: Icon(
        isSelected
            ? Symbols.radio_button_checked_rounded
            : Symbols.radio_button_unchecked_rounded,
        color: isSelected ? Theme.of(ctx).colorScheme.primary : null,
      ),
      title: Text(label),
      onTap: () => Navigator.pop(ctx, value),
    );
  }
}

/// 校验书源配置对话框确认结果（回传值而非 controller）
/// [Task #54 | 2026-08-10] — Qoder
class _CheckSourceConfigResult {
  final String keyword;
  final int seconds;
  final bool checkSearch;
  final bool checkToc;
  final bool checkContent;
  final bool detectCaptcha;
  final bool detectRedirect;

  const _CheckSourceConfigResult({
    required this.keyword,
    required this.seconds,
    required this.checkSearch,
    required this.checkToc,
    required this.checkContent,
    required this.detectCaptcha,
    required this.detectRedirect,
  });
}

/// 校验书源配置对话框（自持 StatefulWidget，照 _TextPromptDialog 模式）：
/// controller 在 State 内创建、dispose 中随子树卸载统一释放，
/// 避免 Navigator.pop 后立即 dispose 在退场动画期间触发
/// framework.dart _dependents.isEmpty 断言红屏。
/// [Task #54 | 2026-08-10] — Qoder
class _CheckSourceConfigDialog extends StatefulWidget {
  final String initialKeyword;
  final int initialSeconds;
  final bool initialCheckSearch;
  final bool initialCheckToc;
  final bool initialCheckContent;
  final bool initialDetectCaptcha;
  final bool initialDetectRedirect;

  const _CheckSourceConfigDialog({
    required this.initialKeyword,
    required this.initialSeconds,
    required this.initialCheckSearch,
    required this.initialCheckToc,
    required this.initialCheckContent,
    required this.initialDetectCaptcha,
    required this.initialDetectRedirect,
  });

  @override
  State<_CheckSourceConfigDialog> createState() =>
      _CheckSourceConfigDialogState();
}

class _CheckSourceConfigDialogState extends State<_CheckSourceConfigDialog> {
  late final TextEditingController _keywordController = TextEditingController(
    text: widget.initialKeyword,
  );
  late final TextEditingController _timeoutController = TextEditingController(
    text: '${widget.initialSeconds}',
  );
  late bool _checkSearch = widget.initialCheckSearch;
  late bool _checkToc = widget.initialCheckToc;
  late bool _checkContent = widget.initialCheckContent;
  late bool _detectCaptcha = widget.initialDetectCaptcha;
  late bool _detectRedirect = widget.initialDetectRedirect;

  /// 超时输入校验错误回显（非空且 > 0 秒，对齐原版 CheckSourceConfig.tvOk）
  String? _timeoutError;

  @override
  void dispose() {
    _keywordController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final text = _timeoutController.text.trim();
    final seconds = int.tryParse(text);
    if (text.isEmpty) {
      setState(() => _timeoutError = '超时时间不能为空');
      return;
    }
    if (seconds == null || seconds <= 0) {
      setState(() => _timeoutError = '超时时间必须大于 0 秒');
      return;
    }
    Navigator.pop(
      context,
      _CheckSourceConfigResult(
        keyword: _keywordController.text.trim(),
        seconds: seconds,
        checkSearch: _checkSearch,
        checkToc: _checkToc,
        checkContent: _checkContent,
        detectCaptcha: _detectCaptcha,
        detectRedirect: _detectRedirect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('校验书源配置'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索关键词',
                  hintText: '默认：我的',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timeoutController,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_timeoutError != null) {
                    setState(() => _timeoutError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: '校验超时（秒）',
                  hintText: '单个校验步骤的超时时间',
                  errorText: _timeoutError,
                ),
              ),
              const SizedBox(height: 8),
              // 校验步骤级联（对齐原版 checkSearch→checkInfo→checkCategory
              // →checkContent 依赖链，映射到 Rust 侧三步开关）
              SettingSwitchRow(
                title: '校验搜索',
                subtitle: '搜索关键词并校验结果',
                value: _checkSearch,
                onChanged: (v) => setState(() {
                  _checkSearch = v;
                  if (!v) {
                    _checkToc = false;
                    _checkContent = false;
                  }
                }),
              ),
              SettingSwitchRow(
                title: '校验目录',
                subtitle: '依赖校验搜索结果',
                value: _checkToc,
                // 上级步骤关闭时下级不可切换（对齐原版 isEnabled 联动）
                onChanged: !_checkSearch
                    ? null
                    : (v) => setState(() {
                        _checkToc = v;
                        if (!v) _checkContent = false;
                      }),
              ),
              SettingSwitchRow(
                title: '校验正文',
                subtitle: '依赖校验目录结果',
                value: _checkContent,
                onChanged: (!_checkSearch || !_checkToc)
                    ? null
                    : (v) => setState(() => _checkContent = v),
              ),
              SettingSwitchRow(
                title: '验证码拦截检测',
                subtitle: '识别疑似验证码页面并标记',
                value: _detectCaptcha,
                onChanged: (v) => setState(() => _detectCaptcha = v),
              ),
              SettingSwitchRow(
                title: '重定向检测',
                subtitle: '识别登录/拦截重定向并标记',
                value: _detectRedirect,
                onChanged: (v) => setState(() => _detectRedirect = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _onConfirm, child: Text(context.l10n.confirm)),
      ],
    );
  }
}

/// MCP 端口输入对话框（自持 StatefulWidget，照 _TextPromptDialog 范式）：
/// controller 在 State 内创建、dispose 中随子树卸载统一释放，
/// 确定先取值再 pop 回传，规避退场动画期间 dispose 引发的框架断言红屏。
/// 留空/0=停止独立服务；>0 校验区间 1024..65530，越界内联报错不 pop。
/// [Task #74 | 2026-08-10] — Qoder
class _McpPortDialog extends StatefulWidget {
  final int currentPort;

  const _McpPortDialog({required this.currentPort});

  @override
  State<_McpPortDialog> createState() => _McpPortDialogState();
}

class _McpPortDialogState extends State<_McpPortDialog> {
  /// 未配置时预填默认端口 1236（Task #76 Med3：落实契约 §2.22.5
  /// 缺省语义，对齐原版 AppConfig.mcpPort 默认值）
  static const int _defaultMcpPort = 1236;

  late final TextEditingController _controller = TextEditingController(
    text: widget.currentPort > 0 ? '${widget.currentPort}' : '$_defaultMcpPort',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context, 0); // 留空=停止独立服务
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) {
      setState(() => _error = '请输入非负数字（0 表示停止）');
      return;
    }
    if (parsed > 0 && (parsed < 1024 || parsed > 65530)) {
      setState(() => _error = '端口区间 1024~65530，0 表示停止');
      return;
    }
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('MCP 服务端口'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '独立 MCP 服务端口（对齐原版默认 1236）；'
            '留空或 0 停止独立服务，Web 端 /mcp/* 不受影响。',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '1024 ~ 65530，0 停止'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _confirm, child: Text(context.l10n.confirm)),
      ],
    );
  }
}

/// 自定义 hosts JSON 编辑对话框（自持 StatefulWidget，照 _TextPromptDialog
/// 范式）：多行编辑 + 预填当前配置，确定回传原始文本，调用方做 JSON 对象
/// 校验（对齐原版 保存/清除/非法不保存 语义）。
/// [Task #74 | 2026-08-10] — Qoder
class _CustomHostsDialog extends StatefulWidget {
  final String initialText;

  const _CustomHostsDialog({required this.initialText});

  @override
  State<_CustomHostsDialog> createState() => _CustomHostsDialogState();
}

class _CustomHostsDialogState extends State<_CustomHostsDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义 hosts'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'JSON 对象格式：{"域名": "IP"} 或 {"域名": ["IP1","IP2"]}；'
            '保存后即时生效，空内容清除并恢复系统 DNS。',
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: TextField(
              controller: _controller,
              autofocus: true,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText: '{"example.com": "1.2.3.4"}',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(context.l10n.confirm),
        ),
      ],
    );
  }
}
