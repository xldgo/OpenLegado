import '../../../l10n/app_localization.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/source_login/source_login_notifier.dart';

/// 书源登录页面
///
/// 支持两种登录方式：
/// 1. WebView 登录（通过外部浏览器打开登录链接，再回填 Cookie）
/// 2. 手动 Cookie 输入
///
/// 登录凭据经 [SourceLoginNotifier] 持久化到 Rust 配置库
/// （SourceLoginRepository，既有 source_login_cache 键），不使用 SharedPreferences。
class SourceLoginScreen extends ConsumerStatefulWidget {
  /// 书源 URL
  final String sourceUrl;

  /// 书源名称
  final String sourceName;

  /// 登录链接（可由书源 loginUrl 字段提供）
  final String? loginUrl;

  /// 共用打开方式，保留本页参数和返回值语义。— Codex + UI
  static Future<bool?> open(
    BuildContext context, {
    required String sourceUrl,
    required String sourceName,
    String? loginUrl,
  }) => Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => SourceLoginScreen(
        sourceUrl: sourceUrl,
        sourceName: sourceName,
        loginUrl: loginUrl,
      ),
    ),
  );

  const SourceLoginScreen({
    super.key,
    required this.sourceUrl,
    required this.sourceName,
    this.loginUrl,
  });

  @override
  ConsumerState<SourceLoginScreen> createState() => _SourceLoginScreenState();
}

class _SourceLoginScreenState extends ConsumerState<SourceLoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // 手动输入控制器（瞬时输入态，提交后落入 Notifier 状态）
  final _cookieNameCtrl = TextEditingController();
  final _cookieValueCtrl = TextEditingController();
  final _headerNameCtrl = TextEditingController();
  final _headerValueCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCredentials());
  }

  @override
  void didUpdateWidget(covariant SourceLoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceUrl != widget.sourceUrl) {
      _tokenCtrl.clear();
      _cookieNameCtrl.clear();
      _cookieValueCtrl.clear();
      _headerNameCtrl.clear();
      _headerValueCtrl.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCredentials());
    }
  }

  Future<void> _loadCredentials() async {
    if (!mounted) return;
    final url = widget.sourceUrl;
    final notifier = ref.read(sourceLoginNotifierProvider(url).notifier);
    final editGeneration = notifier.editGeneration;
    await notifier.load();
    if (mounted &&
        widget.sourceUrl == url &&
        notifier.editGeneration == editGeneration) {
      _tokenCtrl.text = ref.read(sourceLoginNotifierProvider(url)).token;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cookieNameCtrl.dispose();
    _cookieValueCtrl.dispose();
    _headerNameCtrl.dispose();
    _headerValueCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _openLoginUrl() async {
    final l10n = context.l10n;
    final url = widget.loginUrl;
    if (url == null || url.isEmpty) {
      _showSnack(l10n.sourceLoginLinkMissing);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _showSnack(l10n.sourceLoginLinkInvalid);
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack(l10n.sourceLoginLinkOpenFailed);
    }
  }

  void _addCookie() {
    final name = _cookieNameCtrl.text.trim();
    final value = _cookieValueCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack(context.l10n.cookieNameRequired);
      return;
    }
    ref
        .read(sourceLoginNotifierProvider(widget.sourceUrl).notifier)
        .addCookie(name, value);
    _cookieNameCtrl.clear();
    _cookieValueCtrl.clear();
  }

  void _addHeader() {
    final name = _headerNameCtrl.text.trim();
    final value = _headerValueCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack(context.l10n.headerNameRequired);
      return;
    }
    ref
        .read(sourceLoginNotifierProvider(widget.sourceUrl).notifier)
        .addHeader(name, value);
    _headerNameCtrl.clear();
    _headerValueCtrl.clear();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final provider = sourceLoginNotifierProvider(widget.sourceUrl);
    final state = ref.read(provider);
    if (state.isSaving || state.isLoading) return;
    final notifier = ref.read(provider.notifier);
    notifier.setToken(_tokenCtrl.text.trim());
    // [UI_SYNC_REFACTOR R3] 登录 modalOverlay（对齐参考仓 modalOverlay：
    // 提交期间全屏遮罩防重复操作）
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    var saved = false;
    try {
      await notifier.save();
      saved = true;
    } catch (_) {
      if (mounted) _showSnack(l10n.loginSaveFailed);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (mounted && saved) {
      _showSnack(l10n.loginInfoSaved);
      Navigator.of(context).pop(true);
    }
  }

  void _clear() {
    ref.read(sourceLoginNotifierProvider(widget.sourceUrl).notifier).clear();
    _tokenCtrl.clear();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sourceLoginNotifierProvider(widget.sourceUrl));
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(
        title: Text(context.l10n.loginFormTitle(widget.sourceName)),
        bottom: TabBar(
          controller: _tabController,
          // 固定宽度标签等宽铺满，各页面不依赖全局对齐策略。
          tabAlignment: TabAlignment.fill,
          tabs: [
            Tab(text: context.l10n.manualLoginInput),
            Tab(text: context.l10n.loginLink),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.delete_rounded),
            tooltip: context.l10n.clear,
            onPressed: _clear,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildManualTab(state), _buildLoginUrlTab()],
      ),
      bottomBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: state.isSaving ? null : _save,
            icon: state.isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.save_rounded),
            label: Text(context.l10n.saveLoginInfo),
          ),
        ),
      ),
    );
  }

  Widget _buildManualTab(SourceLoginState state) {
    final theme = Theme.of(context);
    return ListView(
      // [LAYOUT_PLAN P2] 页面水平边距统一 16dp（全局标尺）
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          // [LAYOUT_PLAN P2] 字段分组进 Card（圆角 16dp，卡内 16dp）
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.optionalLoginToken,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenCtrl,
                  onChanged: (value) => ref
                      .read(
                        sourceLoginNotifierProvider(widget.sourceUrl).notifier,
                      )
                      .setToken(value),
                  // [LAYOUT_PLAN P2] 输入框走 inputDecorationTheme，不手写边框
                  decoration: InputDecoration(
                    hintText: context.l10n.loginTokenHint,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          // [LAYOUT_PLAN P2] 字段分组进 Card（圆角 16dp，卡内 16dp）
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.loginCookies,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _buildKeyValueRow(
                  nameCtrl: _cookieNameCtrl,
                  valueCtrl: _cookieValueCtrl,
                  nameHint: context.l10n.loginCookieNameHint,
                  valueHint: context.l10n.loginCookieValueHint,
                  onAdd: _addCookie,
                ),
                ...state.cookies.indexed.map(
                  (entry) => ListTile(
                    dense: true,
                    // [LAYOUT_PLAN P2] 组内行 vertical12/horizontal8（全局行规范）
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    title: Text('${entry.$2.name} = ${entry.$2.value}'),
                    trailing: IconButton(
                      icon: const Icon(Symbols.close_rounded),
                      onPressed: () => ref
                          .read(
                            sourceLoginNotifierProvider(widget.sourceUrl)
                                .notifier,
                          )
                          .removeCookie(entry.$1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          // [LAYOUT_PLAN P2] 字段分组进 Card（圆角 16dp，卡内 16dp）
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.optionalLoginHeaders,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _buildKeyValueRow(
                  nameCtrl: _headerNameCtrl,
                  valueCtrl: _headerValueCtrl,
                  nameHint: context.l10n.loginHeaderNameHint,
                  valueHint: context.l10n.loginHeaderValueHint,
                  onAdd: _addHeader,
                ),
                ...state.headers.indexed.map(
                  (entry) => ListTile(
                    dense: true,
                    // [LAYOUT_PLAN P2] 组内行 vertical12/horizontal8（全局行规范）
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    title: Text('${entry.$2.name}: ${entry.$2.value}'),
                    trailing: IconButton(
                      icon: const Icon(Symbols.close_rounded),
                      onPressed: () => ref
                          .read(
                            sourceLoginNotifierProvider(widget.sourceUrl)
                                .notifier,
                          )
                          .removeHeader(entry.$1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyValueRow({
    required TextEditingController nameCtrl,
    required TextEditingController valueCtrl,
    required String nameHint,
    required String valueHint,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: nameCtrl,
            // [LAYOUT_PLAN P2] 输入框走 inputDecorationTheme，不手写边框
            decoration: InputDecoration(hintText: nameHint, isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: valueCtrl,
            // [LAYOUT_PLAN P2] 输入框走 inputDecorationTheme，不手写边框
            decoration: InputDecoration(hintText: valueHint, isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: const Icon(Symbols.add_rounded),
          onPressed: onAdd,
        ),
      ],
    );
  }

  Widget _buildLoginUrlTab() {
    final theme = Theme.of(context);
    final url = widget.loginUrl;
    return Center(
      child: Padding(
        // [LAYOUT_PLAN P2] 页面水平边距统一 16dp（全局标尺）
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Symbols.open_in_browser_rounded, size: 64),
            const SizedBox(height: 16),
            Text(
              url == null || url.isEmpty
                  ? context.l10n.sourceLoginLinkMissing
                  : url,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openLoginUrl,
              icon: const Icon(Symbols.launch_rounded),
              label: Text(context.l10n.openInBrowser),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.browserLoginInstructions,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
