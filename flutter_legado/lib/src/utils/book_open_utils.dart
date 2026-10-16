import 'package:flutter_legado/src/domain/services/book_metadata_policy.dart';
import 'package:flutter_legado/src/domain/services/book_type_policy.dart';

import '../features/book_sources/book_source_repository_provider.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../models/models.dart';
import '../providers/reader/reader_notifier.dart';
import '../routes.dart';
import '../services/platform_bridge_service.dart';

/// 按 BookType 位标记打开阅读器（对齐原版 `startActivityForBook` /
/// `BookInfoActivity.startReadActivity`）。
///
/// 书架已读直开与详情页「开始阅读」共用，避免分流逻辑复制漂移。
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

  /// 路由参数：video/audio 传 [Book]；漫画传 bookUrl；文本阅读器由
  /// ReaderNotifier 持有状态，无 arguments
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

  /// 统一「开书分流」编排（对齐原版 `startActivityForBook` + 未经阅读记录的
  /// 未读进详情语义），4 屏（阅读记录/离线缓存/欢迎页/首页）共用，避免
  /// 「typeBits 解析 + 路由分发」拷贝漂移。
  ///
  /// 流程：
  /// 1. 未读（`durChapterIndex <= 0 && durChapterPos <= 0`）→ 书籍详情页；
  ///    [unreadOpensBookInfo] 为 false 时跳过该分支（供启动默认开读等
  ///    「直达阅读器」场景保持既有行为）；
  /// 2. 在线书籍（[BookMetadataPolicy.isOnlineBook]）按 [Book.origin] 在书源列表匹配
  ///    （两侧去尾斜杠归一后比较，兼容存量源 URL 尾斜杠差异），经
  ///    [BookTypePolicy.resolveTypeBits] 得到最终类型位；匹配失败/异常沿用书籍已有位；
  /// 3. [routeForTypeBits] 选路由：文本阅读器先经 `ReaderNotifier.openBook`
  ///    装载再导航（无 arguments，阅读器状态由 Notifier 持有），
  ///    video/audio/reader-comic 携带 [argumentsForRoute] 参数。
  ///
  /// [useGlobalNavigator] 为 true 时经 [PlatformBridgeService.navigatorKey]
  /// 导航（欢迎页启动直达路径无页面 context 可用）；否则使用 [context]
  /// 的 `Navigator` 并在等待后校验 [BuildContext.mounted]。
  /// — 全栈工程师 + UI
  static Future<void> openBook(
    BuildContext context,
    WidgetRef ref,
    Book book, {
    bool useGlobalNavigator = false,
    bool unreadOpensBookInfo = true,
  }) async {
    final navigator = useGlobalNavigator
        ? PlatformBridgeService.navigatorKey.currentState
        : Navigator.of(context);
    if (navigator == null) return;
    if (unreadOpensBookInfo &&
        book.durChapterIndex <= 0 &&
        book.durChapterPos <= 0) {
      await navigator.pushNamed(AppRoutes.bookInfo, arguments: book);
      return;
    }
    var typeBits = BookTypePolicy.typeBitsOf(book);
    if (BookMetadataPolicy.isOnlineBook(book)) {
      try {
        final sources = await ref
            .read(bookSourceRepositoryProvider)
            .getBookSources();
        String norm(String u) => u.trim().replaceAll(RegExp(r'/+$'), '');
        final o = norm(book.origin);
        for (final s in sources) {
          if (norm(s.bookSourceUrl) == o || s.bookSourceUrl == book.origin) {
            typeBits = BookTypePolicy.resolveTypeBits(typeBits, s);
            break;
          }
        }
      } catch (_) {
        // 书源匹配失败按书籍已有类型位继续（与各屏原兜底一致）
      }
    }
    if (!useGlobalNavigator && !context.mounted) return;
    final bookToOpen = typeBits != 0 ? book.copyWith(bookType: typeBits) : book;
    final route = routeForTypeBits(typeBits);
    if (needsReaderNotifier(route)) {
      ref.read(readerNotifierProvider.notifier).openBook(bookToOpen);
      await navigator.pushNamed(route);
      return;
    }
    await navigator.pushNamed(
      route,
      arguments: argumentsForRoute(route, bookToOpen),
    );
  }
}
