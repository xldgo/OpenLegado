import 'reader_route_entry.dart';
import '../../widgets/book_cover.dart';

import 'package:go_router/go_router.dart';

import 'app_route_page.dart';

import 'package:material_ui/material_ui.dart';

import '../../features/privacy/privacy_screen.dart';
import '../../features/privacy/privacy_gate.dart';

import '../../widgets/reader/read_aloud_player_transition.dart';
import '../../widgets/reader/book_reader_route.dart';

import '../../models/models.dart';
import '../../features/settings/presentation/about_screen.dart';
import '../../features/logs/presentation/app_log_screen.dart';
import '../../features/browser/presentation/browser_screen.dart';
import '../../features/rules/presentation/dict_rule_screen.dart';
import '../../features/dictionary/presentation/dict_screen.dart';
import '../../features/audio/presentation/audio_screen.dart';
import '../../features/automation/presentation/auto_task_screen.dart';
import '../../features/bookshelf/bookshelf.dart';
import '../../features/book_detail/presentation/book_info_screen.dart';
import '../../features/cache/presentation/cache_download_screen.dart';
import '../../features/cache/presentation/cache_settings_screen.dart';
import '../../features/cache/presentation/offline_cache_screen.dart';
import '../../features/book_detail/presentation/edit_book_info_screen.dart';
import '../../features/bookmarks/bookmarks.dart';
import '../../features/book_detail/presentation/change_cover_screen.dart';
import '../../features/book_sources/presentation/change_source_screen.dart';
import '../../features/explore/presentation/explore_show_screen.dart';
import '../../features/files/presentation/file_manage_screen.dart';
import '../../features/reader/presentation/font_screen.dart';
import '../../features/rules/presentation/highlight_rules_screen.dart';
import '../../features/settings/presentation/other_settings_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/imports/presentation/import_screen.dart';
import '../../features/tools/presentation/qrcode_screen.dart';
import '../../features/search/search.dart';
import '../../features/read_records/read_records.dart';
import '../../features/reader_comic/presentation/reader_comic_screen.dart';
import '../../features/remote_books/presentation/remote_book_screen.dart';
import '../../features/rules/presentation/replace_rules_screen.dart';
import '../../features/rules/presentation/replace_rule_edit_screen.dart';
import '../../features/rss/presentation/rss_favorites_screen.dart';
import '../../features/rss/presentation/rss_source_debug_screen.dart';
import '../../features/rss/presentation/rss_source_manage_screen.dart';
import '../../features/rss/presentation/rss_screen.dart';
import '../../features/rules/presentation/rule_sub_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/book_sources/book_sources.dart';
import '../../features/rss/presentation/rss_source_edit_screen.dart';
import '../../features/book_sources/presentation/source_debug_screen.dart';
import '../../features/read_aloud/read_aloud.dart';
import '../../features/read_aloud/presentation/read_aloud_settings_screen.dart';
import '../../features/read_aloud/presentation/read_aloud_player_screen.dart';
import '../../features/appearance/appearance.dart';
import '../../features/appearance/presentation/bottom_bar_skin_screen.dart';
import '../../features/toc/presentation/toc_screen.dart';
import '../../features/rules/presentation/txt_toc_rules_screen.dart';
import '../../features/video/presentation/video_screen.dart';
import '../../features/settings/presentation/webdav_settings_screen.dart';
import '../../features/onboarding/presentation/welcome_config_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';

import 'route_names.dart';
import 'route_arguments.dart';

/// 页面装配由应用入口拥有；每个实例可提供独立路由表。— Codex + UI
class AppRouter {
  AppRouter({Map<String, WidgetBuilder>? routes})
    : routes = Map.unmodifiable(routes ?? _defaultRoutes);

  final Map<String, WidgetBuilder> routes;

  static Map<String, WidgetBuilder> get _defaultRoutes => {
    AppRoutes.home: (_) => const HomeScreen(),
    AppRoutes.reader: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return ReaderRouteEntry(
        bookUrl: switch (args) {
          Book(:final bookUrl) ||
          BookCoverOrigin(:final bookUrl) ||
          ReaderRouteArgs(:final bookUrl) => bookUrl,
          _ => null,
        },
        snapshot: args is Book ? args : null,
      );
    },
    AppRoutes.privacy: (_) => const PrivacyScreen(),
    AppRoutes.readerComic: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final bookUrl = args is String ? args : '';
      return PrivacyBookGate(
        book: Book(bookUrl: bookUrl),
        builder: (_) => ReaderComicScreen(bookUrl: bookUrl),
      );
    },
    AppRoutes.search: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final search = args is SearchRouteArgs ? args : const SearchRouteArgs();
      return SearchScreen(
        initialQuery: search.query,
        initialSourceUrls: search.sourceUrls,
        initialGroups: search.groups,
      );
    },
    AppRoutes.sources: (_) => const SourceScreen(),
    AppRoutes.sourceEdit: (context) {
      // 发现页编辑入口传入完整 BookSource 对象；未传入则新建
      //（此前忽略 arguments → 打开空表单，「编辑页没有书源信息」根因）
      final args = ModalRoute.of(context)?.settings.arguments;
      return SourceEditScreen(source: args is BookSource ? args : null);
    },
    AppRoutes.exploreShow: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final exploreArgs = args is ExploreShowArgs ? args : null;
      return ExploreShowScreen(args: exploreArgs);
    },
    AppRoutes.settings: (_) => const SettingsScreen(),
    AppRoutes.otherSettings: (_) => const OtherSettingsScreen(),
    AppRoutes.cacheSettings: (_) => const CacheSettingsScreen(),
    AppRoutes.cacheDownloads: (_) => const CacheDownloadScreen(),
    AppRoutes.offlineCache: (_) => const OfflineCacheScreen(),
    AppRoutes.rss: (_) => const RssScreen(),
    AppRoutes.ruleSub: (_) => const RuleSubScreen(),
    AppRoutes.audio: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      // 路由参数规范化：优先接收 Book 对象
      if (args is Book) {
        return PrivacyBookGate(
          book: args,
          builder: (_) => AudioScreen(book: args),
        );
      }
      return const AudioScreen();
    },
    AppRoutes.bookInfo: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      // 路由参数规范化：优先接收 Book 对象
      if (args is Book) {
        return PrivacyBookGate(
          book: args,
          builder: (_) => BookInfoScreen(book: args),
        );
      }
      // 向后兼容：支持 String(bookUrl) 传参
      final bookUrl = args is String ? args : '';
      return PrivacyBookGate(
        book: Book(bookUrl: bookUrl),
        builder: (_) => BookInfoScreen(bookUrl: bookUrl),
      );
    },
    AppRoutes.editBookInfo: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      // 路由参数规范化：接收 Book 对象
      if (args is Book) {
        return EditBookInfoScreen(book: args);
      }
      // 缺少书籍对象时回退到首页，避免崩溃
      return const HomeScreen();
    },
    AppRoutes.changeSource: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      // 路由参数规范化：优先接收 Book 对象
      if (args is Book) {
        return ChangeSourceScreen(book: args);
      }
      return const ChangeSourceScreen();
    },
    AppRoutes.readingStats: (_) => const ReadRecordScreen(),
    AppRoutes.readRecord: (_) => const ReadRecordScreen(),
    AppRoutes.readRecordOverview: (_) => const ReadRecordOverviewScreen(),
    AppRoutes.bookmarks: (_) => const BookmarkScreen(),
    AppRoutes.replaceRules: (context) {
      // [UI-fix v2.0.2 | 2026-08-06] 支持 String 路由参数：阅读器长按
      // 选中文本作为新规则 pattern 预填 — Qoder
      final args = ModalRoute.of(context)?.settings.arguments;
      final pattern = args is String ? args : null;
      return ReplaceRulesScreen(initialPattern: pattern);
    },
    AppRoutes.replaceRuleEdit: (context) {
      // [A3 形态对齐 | full-stack-engineer + UI] 替换规则整页编辑器：
      // 路由参数 ReplaceRule（编辑既有规则）或 String（新建时
      // pattern 预填，对标原版 startIntent pattern 预填语义）
      final args = ModalRoute.of(context)?.settings.arguments;
      return ReplaceRuleEditScreen(
        rule: args is ReplaceRule ? args : null,
        prefillPattern: args is String ? args : null,
      );
    },
    AppRoutes.autoTasks: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final task = args is AutoTaskRouteArgs ? args : const AutoTaskRouteArgs();
      return AutoTaskScreen(
        initialEditTaskId: task.editTaskId,
        initialNewTask: task.newTask,
      );
    },
    AppRoutes.sourceDebug: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final sourceUrl = args is String ? args : null;
      return SourceDebugScreen(sourceUrl: sourceUrl);
    },
    AppRoutes.rssSourceEdit: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final source = args is RssSource ? args : null;
      return RssSourceEditScreen(source: source);
    },
    AppRoutes.readAloudConfig: (_) => const ReadAloudConfigScreen(),
    AppRoutes.readAloudSettings: (_) => const ReadAloudSettingsScreen(),
    AppRoutes.readAloudPlayer: (_) => const ReadAloudPlayerScreen(),
    AppRoutes.themeConfig: (_) => const ThemeConfigScreen(),
    AppRoutes.bottomBarSkin: (_) => const BottomBarSkinScreen(),
    AppRoutes.importBooks: (_) => const ImportScreen(),
    AppRoutes.remoteBooks: (_) => const RemoteBookScreen(),
    AppRoutes.bookGroups: (_) => const BookGroupScreen(),
    AppRoutes.bookshelfManage: (_) => const BookshelfManageScreen(),
    AppRoutes.searchContent: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final search = args is ContentSearchRouteArgs ? args : null;
      return SearchContentScreen(
        book: search?.book,
        initialQuery: search?.query,
      );
    },
    AppRoutes.about: (_) => const AboutScreen(),
    // [UI-fix v2.0.3 | 2026-08-08] 独立目录页（对齐原版 TocActivity）：
    // 优先接收 Book 对象，兼容 Map 传参（is Map 运行时判定规范） — Qoder
    AppRoutes.toc: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Book) {
        return TocScreen(book: args);
      }
      // 缺少书籍对象时回退到首页，避免崩溃
      return const HomeScreen();
    },
    AppRoutes.appLog: (_) => const AppLogScreen(),
    AppRoutes.rssSourceManage: (_) => const RssSourceManageScreen(),
    AppRoutes.rssFavorites: (_) => const RssFavoritesScreen(),
    AppRoutes.rssSourceDebug: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final sourceUrl = args is String ? args : null;
      return RssSourceDebugScreen(sourceUrl: sourceUrl);
    },
    AppRoutes.changeCover: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      // 路由参数规范化：优先接收 Book 对象
      if (args is Book) {
        return ChangeCoverScreen(book: args);
      }
      return const ChangeCoverScreen();
    },
    AppRoutes.txtTocRules: (_) => const TxtTocRulesScreen(),
    AppRoutes.dict: (_) => const DictScreen(),
    // [C2 批2 | full-stack-engineer + UI] 字典规则管理页
    AppRoutes.dictRule: (_) => const DictRuleScreen(),
    // [C3 标题字体] 标题字体入口经 arguments 传 'title'（默认 'body' 保持
    // 既有调用方兼容）— full-stack-engineer
    AppRoutes.fonts: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return FontScreen(target: args is String ? args : 'body');
    },
    AppRoutes.highlightRules: (_) => const HighlightRulesScreen(),
    AppRoutes.fileManage: (_) => const FileManageScreen(),
    AppRoutes.qrcode: (_) => const QrcodeScreen(),
    AppRoutes.welcome: (_) => const WelcomeScreen(),
    AppRoutes.welcomeConfig: (_) => const WelcomeConfigScreen(),
    AppRoutes.browser: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final browser = args is BrowserRouteArgs
          ? args
          : const BrowserRouteArgs();
      return BrowserScreen(
        initialUrl: browser.url,
        initialHtml: browser.html,
        title: browser.title,
      );
    },
    AppRoutes.video: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      // [V-B3] 悬浮窗回全屏：原生交回已解析 URL/位置，直接续播
      if (args is VideoScreenArgs) {
        return VideoScreen(
          videoUrl: args.videoUrl,
          title: args.title,
          book: args.book,
          presetUrl: args.presetUrl,
          presetHeaders: args.presetHeaders,
          presetMpdPath: args.presetMpdPath,
          initialResumeMs: args.initialResumeMs,
          initialChapterIndex: args.initialChapterIndex,
          initialSpeed: args.initialSpeed,
          initialPlaying: args.initialPlaying,
        );
      }
      // [UI-fix v2.0.12] 视频源书籍：章节列表 + 当前章播放（对齐原版
      // VideoPlayerActivity 接收 bookUrl 语义）— Reasonix
      if (args is Book) {
        return PrivacyBookGate(
          book: args,
          builder: (_) =>
              VideoScreen(videoUrl: '', title: args.name, book: args),
        );
      }
      return const VideoScreen(videoUrl: '');
    },
    AppRoutes.webdavSettings: (_) => const WebDavSettingsScreen(),
  };

  /// Router实例由App的State持有，主题变化不重建栈。— Codex + UI
  GoRouter createRouter({
    String initialLocation = AppRoutes.home,
    GlobalKey<NavigatorState>? navigatorKey,
    List<NavigatorObserver> observers = const [],
  }) => GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: true,
    observers: observers,
    routes: [
      for (final entry in routes.entries)
        GoRoute(
          path: entry.key,
          name: entry.key,
          pageBuilder: (_, state) => AppRoutePage(
            key: state.pageKey,
            name: entry.key,
            arguments: _arguments(state),
            builder: entry.value,
          ),
        ),
      GoRoute(
        path: '/:unknown(.*)',
        pageBuilder: (_, state) => AppRoutePage(
          key: state.pageKey,
          name: state.uri.path,
          arguments: state.extra,
          builder: routes[AppRoutes.home] ?? (_) => const HomeScreen(),
        ),
      ),
    ],
    errorPageBuilder: (_, state) => AppRoutePage(
      key: state.pageKey,
      name: state.uri.path,
      arguments: _arguments(state),
      builder: routes[AppRoutes.home] ?? (_) => const HomeScreen(),
    ),
  );

  Object? _arguments(GoRouterState state) {
    if (state.extra != null) return state.extra;
    final query = state.uri.queryParameters;
    final bookUrl = query['book'];
    if (state.uri.path == AppRoutes.search) {
      return SearchRouteArgs(
        query: query['q'],
        sourceUrls: state.uri.queryParametersAll['source'],
        groups: state.uri.queryParametersAll['group'],
      );
    }
    if (bookUrl != null && bookUrl.isNotEmpty) {
      if (state.uri.path == AppRoutes.reader) {
        return ReaderRouteArgs(bookUrl: bookUrl);
      }
      if (state.uri.path == AppRoutes.readerComic) return bookUrl;
      if (state.uri.path == AppRoutes.searchContent) {
        return ContentSearchRouteArgs(
          book: Book(bookUrl: bookUrl),
          query: query['q'],
        );
      }
      // 目录/编辑等必须持有完整Book的操作页仍保持缺参回首页，不使用空快照覆盖字段。
      if ({
        AppRoutes.bookInfo,
        AppRoutes.audio,
        AppRoutes.video,
      }.contains(state.uri.path)) {
        return Book(bookUrl: bookUrl);
      }
    }
    return null;
  }

  Route<dynamic> generateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.readAloudPlayer) {
      return ReadAloudPlayerRoute(settings: settings);
    }
    // [A2 形态对齐 | full-stack-engineer + UI] 换源页改用「底部弹层」形态
    // （对标原版 ChangeBookSourceDialog BaseDialogFragment + 参考版 kazusa
    // 底部弹层实机截图）：非不透明路由承载——半透明遮罩压住前页、面板自底部
    // 滑入；5 处调用方仍走 pushNamed 并回收新 bookUrl 路由结果，不改。
    if (settings.name == AppRoutes.changeSource) {
      return ChangeSourceSheetRoute(
        builder: routes[AppRoutes.changeSource]!,
        settings: settings,
      );
    }
    final builder =
        routes[settings.name] ??
        routes[AppRoutes.home] ??
        (_) => const HomeScreen();
    Widget guardedPage(BuildContext context) => PrivacyAppGate(
      child:
          settings.name == AppRoutes.bookGroups ||
              settings.name == AppRoutes.bookshelfManage
          ? PrivacyVerificationGate(builder: builder)
          : Builder(builder: builder),
    );
    if (settings.name == AppRoutes.reader) {
      return BookReaderRoute<dynamic>(builder: guardedPage, settings: settings);
    }
    return MaterialPageRoute<dynamic>(builder: guardedPage, settings: settings);
  }
}
