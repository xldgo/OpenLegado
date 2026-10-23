import '../app/routing/app_navigation.dart';
import '../features/book_detail/book_detail_notifier.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../models/models.dart';
import '../features/reader/application/reader_notifier.dart';
import '../app/routing/route_names.dart';
import '../services/platform_bridge_service.dart';
import '../widgets/book_cover.dart';

/// 按 BookType 位标记打开阅读器（对齐原版 `startActivityForBook` /
/// `BookInfoActivity.startReadActivity`）。
///
/// 书籍直开与详情页「开始阅读」共用类型分流规则。
/// — Reasonix + UI
class BookOpenUtils {
  BookOpenUtils._();

  /// 按类型位选择路由名（video→/video、audio→/audio、image→/reader-comic、
  /// 其余→/reader）
  static String routeForTypeBits(int typeBits) {
    if ((typeBits & BookType.video) != 0) return AppRoutes.video;
    if ((typeBits & BookType.audio) != 0) return AppRoutes.audio;
    if ((typeBits & BookType.image) != 0) return AppRoutes.readerComic;
    return AppRoutes.reader;
  }

  /// 路由参数：video/audio 传 [Book]；漫画传 bookUrl；文字阅读器额外携带
  /// 书籍身份或来源封面，正文状态仍由 ReaderNotifier 持有。
  static Object? argumentsForRoute(String route, Book book) {
    switch (route) {
      case AppRoutes.video:
      case AppRoutes.audio:
        return book;
      case AppRoutes.readerComic:
        return book.bookUrl;
      default:
        return null;
    }
  }

  /// 是否走文本阅读器（需先 openBook 到 ReaderNotifier）
  static bool needsReaderNotifier(String route) => route == AppRoutes.reader;

  /// 统一「开书分流」编排（对齐参考版直接打开阅读器或播放器），
  /// 阅读记录/离线缓存/欢迎页/首页共用，避免
  /// 「typeBits 解析 + 路由分发」拷贝漂移。
  ///
  /// 流程：
  /// 1. 在线书籍（在线书籍）按 [Book.origin] 在书源列表匹配
  ///    （两侧去尾斜杠归一后比较，兼容存量源 URL 尾斜杠差异），经
  ///    BookSourceQueryService.resolveReadingType 得到最终类型位；匹配失败/异常沿用书籍已有位；
  /// 2. [routeForTypeBits] 选路由：文本阅读器先经 `ReaderNotifier.openBook`
  ///    装载再导航（身份及动效来源放入 extra，阅读器状态由 Notifier 持有），
  ///    video/audio/reader-comic 携带 [argumentsForRoute] 参数。
  ///
  /// [useGlobalNavigator] 为 true 时经 [PlatformBridgeService.navigatorKey]
  /// 导航（欢迎页启动直达路径无页面 context 可用）；否则使用 [context]
  /// 的 `Navigator` 并在等待后校验 [BuildContext.mounted]。
  /// [coverContext] 为被点击卡片的上下文，避免同书多次出现时取错封面。
  /// — Codex + UI
  static Future<void> openBook(
    BuildContext context,
    WidgetRef ref,
    Book book, {
    bool useGlobalNavigator = false,
    BuildContext? coverContext,
  }) async {
    final navigator = useGlobalNavigator
        ? PlatformBridgeService.navigatorKey.currentState
        : Navigator.of(context);
    if (navigator == null) return;
    final router = GoRouter.of(navigator.context);
    final prepared = await ref
        .read(bookDetailServiceProvider)
        .resolveReading(book);
    if (!useGlobalNavigator &&
        (!context.mounted || ModalRoute.of(context)?.isCurrent == false)) {
      return;
    }
    final bookToOpen = prepared.book;
    final typeBits = prepared.typeBits;
    final route = routeForTypeBits(typeBits);
    if (needsReaderNotifier(route)) {
      ref.read(readerNotifierProvider.notifier).openBook(bookToOpen);
      final origin = coverContext != null
          ? BookCoverOrigin.fromContext(coverContext, bookToOpen.bookUrl)
          : !useGlobalNavigator
          ? BookCoverHero.originFor(context, bookToOpen.bookUrl)
          : null;
      await router.pushAppRoute(route, extra: origin ?? bookToOpen);
      return;
    }
    await router.pushAppRoute(
      route,
      extra: argumentsForRoute(route, bookToOpen),
    );
  }
}
