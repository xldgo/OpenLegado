import '../../../domain/contracts/source_login_session.dart';
import '../../../l10n/app_localization.dart';
import '../../../widgets/app_menu.dart';

import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../domain/contracts/source_login_repository.dart';
import '../../../services/platform_channel.dart';
import '../../../utils/url_utils.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';
import 'source_login_screen.dart';

/// WebView 登录页（对齐原版 WebViewLoginFragment，UI_MD3_PLAN.md 登录域重构）
///
/// 无 loginUi 表单的书源经 [SourceLoginEntry] 分流进入本页：
/// - 内置 WebView 打开 loginUrl（绝对化 + 书源 header 附加头）；
/// - 页面每次开始/结束加载时读取系统 CookieManager（CookieBridge 通道，
///   对齐原版 CookieManager.getCookie → CookieStore.setCookie 链路），
///   自动落库为书源 loginHeader（{"Cookie": ...}，请求路径由 Rust 自动合并）；
/// - 顶栏「检测」= 重载当前页校验 Cookie，加载完成后提示成功并返回；
/// - 非 http(s) 跳转提示后转外部打开；「手动编辑 Cookie」入口保留既有
///   手动凭据页（菜单次级入口，能力不删）。
class WebViewLoginScreen extends StatefulWidget {
  /// 书源 URL（loginHeader 落库键）
  final String sourceUrl;

  /// 书源名称（顶栏标题）
  final String sourceName;

  /// 登录链接（书源 loginUrl 字段）
  final String loginUrl;

  /// 书源 header 字段原始值（JSON 或 kv 串，解析失败忽略）
  final String? header;

  /// 普通书源凭据与 TTS 会话分开，不依赖根 API。
  final SourceLoginRepository repository;
  final SourceLoginSession? loginSession;

  /// 书源网页共用 Cookie 接线，购买页可隐藏登录专用操作。
  final String? title;
  final bool showLoginActions;

  /// 共用打开方式，保留本页参数和返回值语义。— Codex + UI
  static Future<bool?> open(
    BuildContext context, {
    required String sourceUrl,
    required String sourceName,
    required String loginUrl,
    required SourceLoginRepository repository,
    String? header,
    SourceLoginSession? loginSession,
    String? title,
    bool showLoginActions = true,
  }) => Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => WebViewLoginScreen(
        sourceUrl: sourceUrl,
        sourceName: sourceName,
        loginUrl: loginUrl,
        repository: repository,
        header: header,
        loginSession: loginSession,
        title: title,
        showLoginActions: showLoginActions,
      ),
    ),
  );

  const WebViewLoginScreen({
    super.key,
    required this.sourceUrl,
    required this.sourceName,
    required this.loginUrl,
    this.header,
    required this.repository,
    this.loginSession,
    this.title,
    this.showLoginActions = true,
  });

  /// 解析书源 header 字段为附加请求头（对齐原版 toWebViewRequestConfig：
  /// JSON 对象优先，失败按 k=v&k=v 解析，均失败返回空）。
  /// 静态可测（source_login_screen_test 覆盖）。
  static Map<String, String> parseSourceHeaderMap(String? header) {
    final raw = header?.trim() ?? '';
    if (raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          for (final e in decoded.entries)
            if (e.value != null) e.key.toString(): e.value.toString(),
        };
      }
    } catch (_) {}
    // kv 串兜底：k=v&k2=v2（v 可含 =）
    final map = <String, String>{};
    for (final pair in raw.split('&')) {
      final i = pair.indexOf('=');
      if (i <= 0) continue;
      final k = pair.substring(0, i).trim();
      final v = pair.substring(i + 1).trim();
      if (k.isNotEmpty) map[k] = v;
    }
    return map;
  }

  @override
  State<WebViewLoginScreen> createState() => _WebViewLoginScreenState();
}

class _WebViewLoginScreenState extends State<WebViewLoginScreen> {
  late final WebViewController _controller;
  bool _checking = false;

  /// 当前加载页面 URL（onPageStarted，含跳转后），供主框架 HTTP 错误判定
  String _startedUrl = '';

  @override
  void initState() {
    super.initState();
    final headers = WebViewLoginScreen.parseSourceHeaderMap(widget.header);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _startedUrl = url;
            _syncCookie(url);
          },
          onPageFinished: (url) async {
            _startedUrl = url;
            await _syncCookie(url);
            if (_checking && mounted) {
              setState(() => _checking = false);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(context.l10n.loginCheckCompleted)),
                );
              Navigator.of(context).pop(true);
            }
          },
          // [iOS 视角F A1] 主框架加载失败（网络断开/证书错误等）可见化：
          // 过去失败只留白屏，用户无从归因。
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) {
              _reportLoadFailure(error.description);
            }
          },
          onHttpError: (error) {
            final status = error.response?.statusCode;
            if (status == null || status < 400) return;
            // 主框架判定：iOS WKWebView 的 onHttpError 仅源自主框架导航
            //（request 为 null，子资源不触发）直接提示；Android
            // onReceivedHttpError 对子资源（图片 404 等）也触发，按当前
            // 页面 URL 匹配，避免误报。
            final requestUri = error.request?.uri;
            if (requestUri == null ||
                (_startedUrl.isNotEmpty &&
                    requestUri.toString() == _startedUrl)) {
              _reportLoadFailure('HTTP $status');
            }
          },
          onNavigationRequest: (request) {
            final scheme = Uri.tryParse(request.url)?.scheme ?? '';
            if (scheme != 'http' && scheme != 'https') {
              // 非 http(s) 跳转：提示后转外部打开（对齐原版 longSnackbar）
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.openingExternalApp(request.url)),
                  ),
                );
              }
              launchUrl(
                Uri.parse(request.url),
                mode: LaunchMode.externalApplication,
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    final initialUrl = resolveAbsoluteUrl(widget.sourceUrl, widget.loginUrl);
    if (headers.isEmpty) {
      _controller.loadRequest(Uri.parse(initialUrl));
    } else {
      _controller.loadRequest(Uri.parse(initialUrl), headers: headers);
    }
  }

  /// [iOS 视角F A1] 主框架加载失败上屏提示 + 日志留痕。
  ///
  /// onWebResourceError / onHttpError 同一失败可能先后各触发一次，
  /// hideCurrentSnackBar 去重；「检测」重加载失败时 onPageFinished 不会
  /// 触发，顺带复位 _checking（否则检测转圈永停）。
  void _reportLoadFailure(String reason) {
    if (!mounted) return;
    debugPrint('[WebViewLogin] 主框架加载失败：$reason');
    if (_checking) {
      setState(() => _checking = false);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.loginPageLoadFailed(reason))),
      );
  }

  /// 读取系统 Cookie 并落库 loginHeader（对齐原版 onPageStarted/Finished
  /// 的 CookieManager.getCookie → CookieStore.setCookie）
  ///
  /// [iOS 轨 P2-B] iOS 的 WKWebView Cookie 存于 WKHTTPCookieStore，
  /// webview_flutter 不暴露读取接口——经 JS document.cookie 读取
  /// （局限：httpOnly Cookie 读不到，该类登录态需源在 JS 侧可续期；
  /// Android 通道含 httpOnly 无此限制）
  Future<void> _saveLoginHeader(String json) =>
      widget.loginSession?.putHeader(json) ??
      widget.repository.putLoginHeader(widget.sourceUrl, json);

  Future<void> _syncCookie(String url) async {
    if (Platform.isIOS) {
      try {
        final raw = await _controller.runJavaScriptReturningResult(
          'document.cookie',
        );
        final cookie = raw.toString();
        if (cookie.isEmpty || cookie == 'null') return;
        await _saveLoginHeader(jsonEncode({'Cookie': cookie}));
      } catch (_) {
        // Cookie 读取/落库失败不阻断页面（对齐原版尽力而为语义）
      }
      return;
    }
    try {
      final cookie = await PlatformChannel.getCookie(url);
      if (cookie.isEmpty) return;
      await _saveLoginHeader(jsonEncode({'Cookie': cookie}));
    } catch (_) {
      // Cookie 读取/落库失败不阻断页面（对齐原版尽力而为语义）
    }
  }

  /// 「检测」：重载当前页校验 Cookie，加载完成后返回成功
  Future<void> _verify() async {
    if (_checking) return;
    setState(() => _checking = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.checkingLoginCookies)),
      );
    try {
      await _controller.reload();
    } catch (_) {
      setState(() => _checking = false);
    }
  }

  Future<void> _openManual() async {
    if (widget.loginSession != null) {
      final controller = TextEditingController(
        text: await widget.loginSession!.getHeader(),
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      final value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('登录请求头'),
          content: TextField(controller: controller, maxLines: 5),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (value != null) await widget.loginSession!.putHeader(value);
      return;
    }
    final saved = await SourceLoginScreen.open(
      context,
      sourceUrl: widget.sourceUrl,
      sourceName: widget.sourceName,
      loginUrl: widget.loginUrl,
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      collapsibleTopBar: false,
      topBar: LegadoAppBar(
        title: Text(
          widget.title ?? context.l10n.loginToSource(widget.sourceName),
        ),
        actions: [
          if (_checking)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (widget.showLoginActions)
            IconButton(
              icon: const Icon(Symbols.fact_check_rounded),
              tooltip: context.l10n.checkLoginAction,
              onPressed: _checking ? null : _verify,
            ),
          AppMenuButton<String>(
            tooltip: context.l10n.moreOptions,
            // [LAYOUT_PLAN P2] 菜单在顶栏下方展开，不覆盖顶栏
            onSelected: (value) {
              switch (value) {
                case 'manual':
                  _openManual();
                case 'open_external':
                  _openExternal();
              }
            },
            itemBuilder: (ctx) => [
              if (widget.showLoginActions)
                AppMenuItem(
                  value: 'manual',
                  child: Text(ctx.l10n.editLoginCookies),
                ),
              AppMenuItem(
                value: 'open_external',
                child: Text(ctx.l10n.openInBrowser),
              ),
            ],
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(
      resolveAbsoluteUrl(widget.sourceUrl, widget.loginUrl),
    );
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
