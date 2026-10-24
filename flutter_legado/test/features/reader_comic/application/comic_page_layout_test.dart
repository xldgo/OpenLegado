import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/reader_comic/application/comic_page_layout.dart';

/// 复用上游MangaReaderInteractionTest的拆分顺序/迟到尺寸样例。— Codex + UI
void main() {
  test('宽页按阅读方向拆为两半，竖图和原图索引保持不变', () {
    List<ComicPageSlot> pages(bool reversed) => buildComicPageSlots(
      imageCount: 3,
      wideImages: {0, 2},
      splitWidePages: true,
      rightToLeft: reversed,
    );
    expect(pages(false), [
      (imageIndex: 0, slice: ComicPageSlice.left),
      (imageIndex: 0, slice: ComicPageSlice.right),
      (imageIndex: 1, slice: ComicPageSlice.full),
      (imageIndex: 2, slice: ComicPageSlice.left),
      (imageIndex: 2, slice: ComicPageSlice.right),
    ]);
    expect(pages(true).map((page) => page.slice), [
      ComicPageSlice.right,
      ComicPageSlice.left,
      ComicPageSlice.full,
      ComicPageSlice.right,
      ComicPageSlice.left,
    ]);
    expect(
      buildComicPageSlots(
        imageCount: 3,
        wideImages: {0, 2},
        splitWidePages: false,
        rightToLeft: true,
      ).map((page) => page.imageIndex),
      [0, 1, 2],
    );
  });

  test('迟到尺寸与阅读方向变化保留当前第二半，拆分关闭后回到同一原图', () {
    final changed = buildComicPageSlots(
      imageCount: 3,
      wideImages: {0, 2},
      splitWidePages: true,
      rightToLeft: false,
    );
    expect(changed[comicPageSlotTarget(changed, 0, ComicPageSlice.right)], (
      imageIndex: 0,
      slice: ComicPageSlice.right,
    ));
    final reversed = buildComicPageSlots(
      imageCount: 3,
      wideImages: {0, 2},
      splitWidePages: true,
      rightToLeft: true,
    );
    expect(reversed[comicPageSlotTarget(reversed, 0, ComicPageSlice.right)], (
      imageIndex: 0,
      slice: ComicPageSlice.right,
    ));
    final normal = buildComicPageSlots(
      imageCount: 3,
      wideImages: {0, 2},
      splitWidePages: false,
      rightToLeft: false,
    );
    expect(normal[comicPageSlotTarget(normal, 2, ComicPageSlice.right)], (
      imageIndex: 2,
      slice: ComicPageSlice.full,
    ));
  });
}
