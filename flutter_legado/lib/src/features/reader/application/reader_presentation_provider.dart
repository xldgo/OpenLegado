import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/comic_image_utils.dart';
import '../../audio/application/audio_notifier.dart';
import 'reader_notifier.dart';

/// 可注入分类函数，仅在章节文本改变时执行；普通进度和菜单更新复用结果。— Codex + UI
final readerContentClassifierProvider = Provider<bool Function(String)>(
  (ref) => isImageDominantContent,
);
final readerImageDominantProvider = Provider<bool>((ref) {
  final content = ref.watch(
    readerNotifierProvider.select((s) => s.chapterContent),
  );
  return content.isNotEmpty &&
      ref.watch(readerContentClassifierProvider)(content);
});

/// 页面组合只观察实际消费的字段；页码/总页数由正文和菜单各自订阅。
/// 返回依赖记录而不制造进度归零的伪ReaderState。
final readerScreenDependenciesProvider = Provider(
  (ref) => ref.watch(
    readerNotifierProvider.select(
      (s) => (
        s.currentBook,
        s.chapters,
        s.currentChapterIndex,
        s.chapterContent,
        s.isLoading,
        s.error,
        s.showControls,
        s.fontSize,
        s.lineHeight,
        s.backgroundColor,
        s.foregroundColor,
        s.readingBrightness,
        s.pageTurnMode,
      ),
    ),
  ),
);

final readerReadAloudActiveProvider = Provider<bool>((ref) {
  final bookUrl = ref.watch(
    readerNotifierProvider.select((s) => s.currentBook?.bookUrl),
  );
  return ref.watch(
    audioNotifierProvider.select(
      (audio) =>
          bookUrl != null &&
          audio.bookUrl == bookUrl &&
          audio.state != PlayerState.idle,
    ),
  );
});
