import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/bookshelf/bookshelf_repositories.dart';
import '../../models/book.dart';
import '../../providers/general_settings_provider.dart';

/// 冷启动「默认进入阅读」的目标解析（对齐上游 MainActivity.shouldApplyDefaultToRead）。
///
/// 上游不经过任何闪屏或计时器：MainActivity 起始栈里直接追加阅读页
/// （`defaultToRead && resolved == MainRouteHome -> [Home, ReadBook]`，
/// 且只在 `savedInstanceState == null` 时生效）。
///
/// 本项目没有 Android 那套 Nav 起始栈，改由 `StartupReadingNavigation`
/// 在主页真正入栈后打开，因此这里只负责解析目标书籍：书架中
/// `durChapterTime` 最大且确实读过正文（>0）的那本。
///
/// 只在应用容器生命周期内解析一次（FutureProvider 缓存），相当于上游
/// 的 cold-start-only 语义；从后台返回或页面间来回不会重复触发。— Codex + UI
final startupDefaultToReadProvider = FutureProvider<Book?>((ref) async {
  final repository = ref.read(generalSettingsRepositoryProvider);
  try {
    await repository.load();
  } catch (error) {
    debugPrint('[启动] 读取「默认进入阅读」设置失败：$error');
    return null;
  }
  if (!repository.current.defaultToRead) return null;

  try {
    final books = await ref.read(bookshelfRepositoryProvider).getBooks();
    Book? lastRead;
    for (final book in books) {
      if (book.durChapterTime <= 0) continue;
      if (lastRead == null || book.durChapterTime > lastRead.durChapterTime) {
        lastRead = book;
      }
    }
    return lastRead;
  } catch (error) {
    debugPrint('[启动] 解析上次阅读书籍失败：$error');
    return null;
  }
});
