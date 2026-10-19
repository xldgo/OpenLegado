import 'src/data/services/file_metadata.dart';
import 'src/app/routing/startup_default_to_read.dart';
import 'src/app/routing/startup_reading_navigation.dart';
import 'src/app/routing/app_navigation.dart';
import 'src/providers/auto_task/auto_task_dependencies.dart';
import 'src/providers/config_settings_provider.dart';

import 'dart:async';
import 'dart:io' show File, FileSystemEntityType;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import 'src/models/models.dart';
import 'src/l10n/app_strings.dart';
import 'src/l10n/app_localization.dart';
import 'src/providers/app_locale_notifier.dart';
import 'src/providers/theme/app_theme_preferences_provider.dart';
import 'src/providers/theme/theme_colors_notifier.dart';
import 'src/providers/theme/theme_notifier.dart';
import 'src/app/routing/route_names.dart';
import 'src/app/routing/route_arguments.dart';
import 'src/app/routing/app_router.dart';
import 'src/services/auto_task_scheduler.dart';
import 'src/services/crash_log_service.dart';
import 'src/services/deep_link_service.dart';
import 'src/features/audio/application/audio_notifier.dart';
import 'src/features/read_aloud/media_playback_navigation.dart';
import 'src/services/platform_bridge_service.dart';
import 'src/services/video_float_window.dart';
import 'src/theme/app_theme_resolver.dart';
import 'src/theme/app_glass_theme.dart';

import 'package:dynamic_color/dynamic_color.dart';

import 'src/utils/app_route_observer.dart';
import 'src/utils/app_scroll_behavior.dart';
import 'src/widgets/system_bar_binder.dart';
import 'src/widgets/ui_settings_scope.dart';
import 'src/widgets/eye_protection_filter.dart';
import 'src/widgets/crash_log_dialog.dart';
import 'src/widgets/verification_code_listener.dart';
import 'src/widgets/webview_bridge_listener.dart';
import 'src/widgets/reader/read_aloud_capsule_host.dart';

/// Legado App 入口 Widget
class LegadoApp extends ConsumerStatefulWidget {
  /// 初始路由（冷启动直接进主页，闪屏由系统启动画面负责，对齐上游）
  final String initialRoute;

  /// 上次崩溃日志内容（null 表示无崩溃记录）
  final String? lastCrashLog;

  /// 启动阶段已成功预热；独立预览默认使用普通材质。
  final bool glassAvailable;

  const LegadoApp({
    super.key,
    this.initialRoute = AppRoutes.home,
    this.lastCrashLog,
    this.glassAvailable = false,
  });

  /// 弹出「上次运行发生崩溃」提示弹窗（[P2-13 2026-09-18]）。
  ///
  /// 弹窗必须挂在 [MaterialApp.navigatorKey]（即
  /// [PlatformBridgeService.navigatorKey]，见 [build]）的 **Navigator 自身
  /// context** 上，而不是构建 [MaterialApp] 的 State 的 context：
  /// 后者是 Navigator 的祖先，`showDialog` → `Navigator.of(context)` 只能
  /// **向上** 查找，其上方没有 Navigator（Navigator 是它的后代）→
  /// `Null check operator used on a null value`。该异常被 main.dart 注册的
  /// `FlutterError.onError` 捕获后 `CrashLogService.logError` 重写
  /// `crash_log.txt` 并重新置崩溃标记 → 下次启动再次弹窗再次抛异常，
  /// 形成启动崩溃循环（crash_log.txt 每次启动都被刷新）。
  ///
  /// 首帧渲染完成时 [MaterialApp] 已构建、Navigator 已挂载，
  /// `navigatorKey.currentContext` 非空，`showDialog` 自该 context 向上
  /// 即可命中本 Navigator（与 [PlatformBridgeService] L661、
  /// [DeepLinkService] attach 模式同源）。
  ///
  /// 返回是否已调度弹窗；Navigator 尚未装配（如宿主未挂
  /// [PlatformBridgeService.navigatorKey]）时静默跳过本轮——崩溃日志
  /// 仍留在磁盘文件中，下次启动继续提示，不丢数据、不抛异常。
  static bool showCrashLogDialog(String crashLog) {
    final navContext = PlatformBridgeService.navigatorKey.currentContext;
    if (navContext == null) return false;
    CrashLogDialog.show(navContext, crashLog);
    return true;
  }

  /// 调度「上次崩溃」弹窗（P2-13）。
  ///
  /// 弹窗必须等 Navigator 装配完成后才能弹出（见 [showCrashLogDialog]）：
  /// 冷启动首帧 [MaterialApp] 尚未构建、`navigatorKey.currentContext` 为空，
  /// 故逐帧重试，装配成功即返回并停止；[maxFrames] 帧内仍未就绪则放弃本次
  /// 提示——崩溃日志仍在磁盘文件中，下次启动继续提示，不丢数据、不抛异常。
  ///
  /// 历史：P2-13b 曾在这里等待闪屏 /welcome 退出后再弹，避免弹窗路由被
  /// `pushReplacement(home)` 连同替换。闪屏路由已按上游移除（冷启动直接进
  /// 主页），该等待条件随之取消。
  ///
  /// [isAlive] 供宿主 State 传入 `() => mounted`：State 已卸载即停止
  /// 重试，避免对已销毁界面弹窗。
  static void scheduleCrashLogDialog(
    String crashLog,
    bool Function() isAlive, {
    int maxFrames = 90,
  }) {
    var shown = false;

    void attempt(int frame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isAlive() || shown) return;
        if (showCrashLogDialog(crashLog)) {
          shown = true;
          return;
        }
        if (frame < maxFrames) attempt(frame + 1);
      });
      // 主动预约下一帧：否则重试只会在其他原因触发重绘时才推进，
      // 启动阶段可能长时间停留在「未尝试」状态。
      WidgetsBinding.instance.scheduleFrame();
    }

    attempt(0);
  }

  /// [V-B3-ROUTE 2026-10-05] 悬浮窗/深链回全屏导航调度：等 Navigator 就绪。
  ///
  /// 冷启动首帧前 `navigatorKey.currentState` 为空，此时直接 push 会丢失导航；
  /// 故按 [interval] 轮询（默认 50ms × [maxAttempts] = 3s 上限），就绪即执行，
  /// 超时回调 [onTimeout]（宁可不导航，停留当前页）。
  ///
  /// 历史：闪屏 /welcome 存续期间压栈会被 `pushReplacement(home)` 整体替换
  /// （round2 真机 2/2，`.tmp/video_qa/round2/c2_*.png`），故曾以
  /// `TopRouteWatcher` 门控「栈顶已非 /welcome」。闪屏路由已按上游移除，
  /// 门控退化为「Navigator 是否就绪」。
  static void scheduleFloatReturnNavigation({
    required NavigatorState? Function() navigator,
    required void Function(NavigatorState navigator) push,
    int maxAttempts = 60,
    Duration interval = const Duration(milliseconds: 50),
    VoidCallback? onTimeout,
    bool Function()? isAlive,
  }) {
    void attempt(int attemptNo) {
      if (isAlive != null && !isAlive()) return;
      final nav = navigator();
      if (nav != null) {
        push(nav);
        return;
      }
      if (attemptNo >= maxAttempts) {
        onTimeout?.call();
        return;
      }
      Timer(interval, () => attempt(attemptNo + 1));
    }

    attempt(0);
  }

  @override
  ConsumerState<LegadoApp> createState() => _LegadoAppState();
}

class _LegadoAppState extends ConsumerState<LegadoApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  late final StartupReadingNavigation _startupReading;
  late final ProviderContainer _applicationContainer;
  final _initialDeepLinkReady = Completer<void>();

  final _readAloudCapsuleObserver = ReadAloudCapsuleObserver();
  late final MediaPlaybackNavigation _mediaPlaybackNavigation;

  @override
  void initState() {
    super.initState();
    _applicationContainer = ProviderScope.containerOf(context, listen: false);
    _startupReading = ref.read(startupReadingNavigationProvider);
    _mediaPlaybackNavigation = MediaPlaybackNavigation(
      onOpenRequested: _startupReading.preferExternalAction,
      resolve: (request) {
        if (!mounted) return null;
        final notifier = ref.read(audioNotifierProvider.notifier);
        if (!notifier.ownsMediaTarget(request, matchChapter: false)) {
          return null;
        }
        final audio = ref.read(audioNotifierProvider);
        return MediaPlaybackDestination(
          audio.isStreamMode ? AppRoutes.audio : AppRoutes.readAloudPlayer,
          book:
              notifier.currentBook ??
              Book(
                bookUrl: audio.bookUrl,
                name: audio.bookName,
                bookType: audio.isStreamMode ? BookType.audio : BookType.text,
              ),
        );
      },
    );
    _router = AppRouter().createRouter(
      initialLocation: widget.initialRoute,
      navigatorKey: PlatformBridgeService.navigatorKey,
      observers: [
        appRouteObserver,
        systemBarRouteObserver,
        _startupReading,
        _readAloudCapsuleObserver,
        _mediaPlaybackNavigation,
      ],
    );
    // 冷启动「默认进入阅读」：解析一次（详见 startupDefaultToReadProvider），
    // 交给 _startupReading 在主页入栈后打开。对齐上游
    // MainActivity.shouldApplyDefaultToRead——无闪屏、无计时器。
    unawaited(
      ref.read(startupDefaultToReadProvider.future).then((book) {
        if (book != null && mounted) _startupReading.request(book);
      }),
    );
    final initialMedia = _mediaPlaybackNavigation.attach(
      ref.read(audioServiceProvider),
    );
    WidgetsBinding.instance.addObserver(this);
    // 系统栏样式由 [SystemBarBinder] 按偏好与主题统一驱动
    // 首帧渲染后检查上次崩溃日志并弹窗提示
    // [P2-13 2026-09-18] 弹窗上下文改用全局 Navigator（见
    // [showCrashLogDialog]）：本 State 自身 context 是 MaterialApp 的
    // **祖先**，showDialog 向上找 Navigator 时其上方并无 Navigator
    // （Navigator 是它的后代）→ 抛异常 → FlutterError.onError 重写
    // crash_log.txt 并置崩溃标记 → 下次启动再弹再抛，形成启动崩溃循环。
    // [P2-13b 2026-09-19] 闪屏存续期间弹窗路由会被 `pushReplacement(home)`
    // 一并替换（弹窗一闪即逝），当时以 TopRouteWatcher 等闪屏退出；闪屏
    // 路由已按上游移除，现只等 Navigator 装配（逐帧重试 + 90 帧上限）。
    if (widget.lastCrashLog != null && widget.lastCrashLog!.isNotEmpty) {
      LegadoApp.scheduleCrashLogDialog(widget.lastCrashLog!, () => mounted);
    }
    // [UI-fix v2.0.3 | 2026-08-08] 定时任务应用内调度器启动装配
    //（Task #146，对齐原版 App.kt 启动时 AutoTaskScheduler.refresh；
    // 引擎已在 main.dart 先行初始化，此处可直接读取领域Provider） — QoderCN

    final taskSettings = ref.read(serviceSettingsRepositoryProvider);
    AutoTaskScheduler.instance.attach(
      repository: ref.read(autoTaskRepositoryProvider),
      service: ref.read(autoTaskServiceProvider),
      readEnabled: () async => (await taskSettings.load()).autoTaskEnabled,
    );
    // P1-11：监听系统 legado:// / yuedu:// 深链 → Association
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 等 Navigator 装配后再 attach（冷启动首帧前 navigatorKey 为空）。
      LegadoApp.scheduleFloatReturnNavigation(
        isAlive: () => mounted,
        navigator: () =>
            mounted ? PlatformBridgeService.navigatorKey.currentState : null,
        push: (_) {
          unawaited(
            DeepLinkService.instance
                .attach(
                  PlatformBridgeService.navigatorKey,
                  onImport: _startupReading.preferExternalAction,
                )
                .then(
                  (_) => _completeInitialDeepLink(),
                  onError: (Object error, StackTrace stack) {
                    if (!_initialDeepLinkReady.isCompleted) {
                      _initialDeepLinkReady.completeError(error, stack);
                    }
                  },
                ),
          );
        },
        onTimeout: () {
          _startupReading.preferExternalAction();
          _completeInitialDeepLink();
          debugPrint('[DeepLink] 等待 Navigator 就绪超时');
        },
      );
    });
    // [V-B3] 视频悬浮窗：注册原生事件处理与回全屏导航后 attach
    // （attach 会拉取冷启动经 MainActivity Intent 带回的播放状态）
    VideoFloatWindowCoordinator.instance
      ..openFullscreen = _openVideoFromFloatWindow
      ..onNotice = _showFloatWindowNotice;
    final initialVideo = VideoFloatWindowBridge.instance.attach();
    _startupReading.waitForInitialActions(
      Future.wait<void>([
        _initialDeepLinkReady.future,
        initialMedia,
        initialVideo,
      ]),
    );
  }

  void _completeInitialDeepLink() {
    if (!_initialDeepLinkReady.isCompleted) _initialDeepLinkReady.complete();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (ref.read(appLocaleProvider) == 'system') setState(() {});
  }

  @override
  void dispose() {
    _completeInitialDeepLink();
    AutoTaskScheduler.instance.detach();
    unawaited(DeepLinkService.instance.detach());
    VideoFloatWindowBridge.instance.detach();
    VideoFloatWindowCoordinator.instance
      ..openFullscreen = null
      ..onNotice = null;
    unawaited(CrashLogService.instance.flush());
    _startupReading.dispose();
    _applicationContainer.invalidate(startupReadingNavigationProvider);
    _router.dispose();
    _mediaPlaybackNavigation.dispose();
    _readAloudCapsuleObserver.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// [V-B3] 悬浮窗「全屏」/通知点击回传：导航到视频页从交回位置续播
  ///
  /// [V-B3-ROUTE] 冷启动首帧前 Navigator 未装配，压栈会丢失；改为轮询等
  /// Navigator 就绪后再压入 /video（详见 [scheduleFloatReturnNavigation]）。
  void _openVideoFromFloatWindow(VideoFloatWindowState state, Book? book) {
    if (!mounted) return;
    _startupReading.preferExternalAction();
    final args = VideoScreenArgs(
      videoUrl: state.directUrl ?? book?.bookUrl ?? '',
      title: state.chapterTitle?.isNotEmpty == true
          ? state.chapterTitle!
          : (state.title.isNotEmpty ? state.title : '视频播放'),
      book: book,
      presetUrl: state.url,
      presetHeaders: state.headers,
      presetMpdPath: state.mpdTempPath,
      initialResumeMs: state.positionMs,
      initialChapterIndex: state.chapterIndex >= 0 ? state.chapterIndex : null,
      initialSpeed: state.speed,
      initialPlaying: state.playing,
    );
    // 就绪循环：冷启动首帧前 Navigator 未装配（原 addPostFrameCallback
    // 推迟逻辑的等价物）。
    LegadoApp.scheduleFloatReturnNavigation(
      isAlive: () => mounted,
      navigator: () => PlatformBridgeService.navigatorKey.currentState,
      push: (navigator) =>
          GoRouter.of(navigator.context)
              .pushAppRoute(AppRoutes.video, extra: args),
      onTimeout: () =>
          debugPrint('[VideoFloat] Navigator 未在等待窗口内就绪，放弃本次回全屏导航（停留当前页）'),
    );
  }

  /// [V-B3] 悬浮窗用户可见提示（经全局 Navigator context）
  void _showFloatWindowNotice(String message) {
    final context = PlatformBridgeService.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeNotifierProvider);
    final localePreference = ref.watch(appLocaleProvider);
    final locale = resolveAppLocale(
      localePreference,
      WidgetsBinding.instance.platformDispatcher.locales,
    );
    AppStrings.setLocale(locale.languageCode);
    final themeColors = ref.watch(themeColorsProvider);
    final preferences = ref.watch(appThemePreferencesProvider);

    // 平台动态色与本地背景图由应用入口提供，主题解析只消费绘制输入。
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final themes = resolveAppThemes(
          preferences: preferences,
          lightDynamic: lightDynamic,
          darkDynamic: darkDynamic,
        );
        final lightTheme = _withOptionalTransparentScaffold(
          themes.light,
          themeColors.bgImage,
        );
        final darkTheme = _withOptionalTransparentScaffold(
          themes.dark,
          themeColors.bgImageNight,
        );

        return MaterialApp.router(
          onGenerateTitle: (context) => context.l10n.appTitle,
          // [UI-FIX v2.0.2 | 2026-08-06] 平台桥接服务经此 Key 分发页面跳转 / SnackBar
          //（Task #114，服务层无 BuildContext） — QoderCN
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: appSupportedLocales,
          locale: locale,
          theme: lightTheme,
          darkTheme: darkTheme,
          // 主题模式由 ThemeNotifier 驱动（亮/暗/跟随系统，全局实时切换）
          themeMode: themeState.themeMode,
          // 全局统一滚动物理（BouncingScrollPhysics，对齐安卓原版回弹手感）
          scrollBehavior: AppScrollBehavior(),
          // 全局字体缩放：对齐原版 AppContextWrapper.getFontScale
          // （fontScale 为 null 表示跟随系统，不覆盖平台缩放）
          builder: (context, child) {
            final scale = themeState.fontScale;
            // 全局验证码请求监听（对标原版 SourceVerificationHelp 全局监听，
            // 书源 JS 挂起等待验证码时跨页面弹窗）
            Widget wrapped = VerificationCodeListener(
              navigatorKey: PlatformBridgeService.navigatorKey,
              child: child!,
            );
            // BackstageWebView DOM 通道（@webjs / 正文 webJs / java.webView*）
            wrapped = WebViewBridgeListener(child: wrapped);
            // 普通页面系统栏跟随主题；阅读器显隐由页面归属控制器接管。
            wrapped = SystemBarBinder(child: wrapped);
            // P1-8：按当前亮度叠全局背景图（分组卡片仍自带不透明底，可读性保留）
            wrapped = _ThemeBackgroundLayer(
              path: themeColors.bgImageFor(
                isNight: Theme.of(context).brightness == Brightness.dark,
              ),
              child: wrapped,
            );
            // Markdown 等第三方组件仍从上下文读取旧设计库主题与本地化。
            // ignore: deprecated_member_use
            wrapped = MaterialUiCompatibilityBridge(child: wrapped);
            wrapped = ReadAloudCapsuleHost(
              observer: _readAloudCapsuleObserver,
              child: wrapped,
            );
            wrapped = EyeProtectionFilter(child: wrapped);
            wrapped = UiSettingsHost(child: wrapped);
            wrapped = AppGlassHost(
              available: widget.glassAvailable,
              child: wrapped,
            );
            if (scale == null) return wrapped;
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: wrapped,
            );
          },
        );
      },
    );
  }

  /// 本地背景图可用时让 Scaffold 透明，露出下层壁纸
  ThemeData _withOptionalTransparentScaffold(ThemeData base, String path) {
    if (ref.watch(fileMetadataProvider(path)).value?.type !=
        FileSystemEntityType.file) {
      return base;
    }
    return base.copyWith(scaffoldBackgroundColor: Colors.transparent);
  }
}

/// 全局主题背景图层（对齐原版 ThemeConfig.getBgImage）
class _ThemeBackgroundLayer extends ConsumerWidget {
  final String path;
  final Widget child;

  const _ThemeBackgroundLayer({required this.path, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(fileMetadataProvider(path)).value?.type !=
        FileSystemEntityType.file) {
      return child;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: FileImage(File(path)),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: child,
    );
  }
}
