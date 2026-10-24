import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/reader_comic/application/comic_page_layout.dart';
import 'package:flutter_legado/src/models/manga_page_scale_type.dart';

/// 复用上游MangaReaderInteractionTest的配对/宽页/重排样例。— Codex + UI
void main() {
  List<ComicPageSpread> layout({
    int count = 4,
    Set<int> wide = const {},
    bool split = false,
    bool reversed = false,
    bool doublePage = true,
    bool cover = false,
    bool shift = false,
  }) => buildComicPageSpreads(
    imageCount: count,
    wideImages: wide,
    splitWidePages: split,
    rightToLeft: reversed,
    doublePage: doublePage,
    coverSingle: cover,
    shiftPairing: shift,
  );
  List<List<int>> indices(List<ComicPageSpread> spreads) => [
    for (final spread in spreads)
      spread.slots.map((slot) => slot.imageIndex).toList(),
  ];

  test('竖图配对，宽图独立；封面单页/错位使章节首图独立且不叠加跳过', () {
    expect(indices(layout(count: 5)), [
      [0, 1],
      [2, 3],
      [4],
    ]);
    expect(indices(layout(wide: {0, 3})), [
      [0],
      [1, 2],
      [3],
    ]);
    for (final rule in [(true, false), (false, true), (true, true)]) {
      expect(indices(layout(cover: rule.$1, shift: rule.$2)), [
        [0],
        [1, 2],
        [3],
      ]);
    }
    expect(indices(layout(doublePage: false)), [
      [0],
      [1],
      [2],
      [3],
    ]);
    expect(layout(count: 0), isEmpty);
    expect(
      MangaDoublePageMode.isActive(MangaDoublePageMode.landscape, 1000, 600),
      isTrue,
    );
    expect(
      MangaDoublePageMode.isActive(MangaDoublePageMode.landscape, 600, 1000),
      isFalse,
    );
  });

  test('宽页拆分优先于配对，半页按阅读方向排列且不与邻图配对', () {
    final forward = layout(count: 3, wide: {0}, split: true);
    expect(indices(forward), [
      [0],
      [0],
      [1, 2],
    ]);
    expect(forward.take(2).map((spread) => spread.first.slice), [
      ComicPageSlice.left,
      ComicPageSlice.right,
    ]);
    final backward = layout(count: 3, wide: {0}, split: true, reversed: true);
    expect(backward.take(2).map((spread) => spread.first.slice), [
      ComicPageSlice.right,
      ComicPageSlice.left,
    ]);
    expect(indices(backward), [
      [0],
      [0],
      [1, 2],
    ]);
  });

  test('尺寸/方向变化优先保留完整显示页，身份失效回到同一原图或半页', () {
    final before = layout(count: 3, wide: {0}, split: true);
    final right = before[1];
    final changed = layout(count: 3, wide: {0, 2}, split: true, reversed: true);
    expect(
      changed[comicPageSpreadTarget(
        changed,
        0,
        ComicPageSlice.right,
        previous: right,
      )],
      right,
    );
    final paired = layout(count: 3);
    final separated = layout(count: 3, wide: {0});
    final target = comicPageSpreadTarget(
      separated,
      1,
      ComicPageSlice.full,
      previous: paired.first,
    );
    expect(separated[target].first.imageIndex, 1);
    final normal = layout(count: 3, doublePage: false);
    expect(
      normal[comicPageSpreadTarget(
            normal,
            0,
            ComicPageSlice.right,
            previous: right,
          )]
          .first,
      (imageIndex: 0, slice: ComicPageSlice.full),
    );
  });
}
