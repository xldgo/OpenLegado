/// 显示页与原图分离，对齐参考版MangaPageSpread。— Codex + UI
enum ComicPageSlice { full, left, right }

typedef ComicPageSlot = ({int imageIndex, ComicPageSlice slice});
typedef ComicPageSpread = ({ComicPageSlot first, ComicPageSlot? second});

extension ComicPageSpreadSlots on ComicPageSpread {
  Iterable<ComicPageSlot> get slots sync* {
    yield first;
    if (second case final second?) yield second;
  }
}

List<ComicPageSpread> buildComicPageSpreads({
  required int imageCount,
  required Set<int> wideImages,
  required bool splitWidePages,
  required bool rightToLeft,
  bool doublePage = false,
  bool coverSingle = false,
  bool shiftPairing = false,
}) {
  final spreads = <ComicPageSpread>[];
  var index = 0;
  while (index < imageCount) {
    final wide = wideImages.contains(index);
    if (wide && splitWidePages) {
      for (final slice
          in rightToLeft
              ? [ComicPageSlice.right, ComicPageSlice.left]
              : [ComicPageSlice.left, ComicPageSlice.right]) {
        spreads.add((first: (imageIndex: index, slice: slice), second: null));
      }
      index++;
    } else {
      final pair =
          doublePage &&
          !(index == 0 && (coverSingle || shiftPairing)) &&
          index + 1 < imageCount &&
          !wide &&
          !wideImages.contains(index + 1);
      spreads.add((
        first: (imageIndex: index, slice: ComicPageSlice.full),
        second: pair
            ? (imageIndex: index + 1, slice: ComicPageSlice.full)
            : null,
      ));
      index += pair ? 2 : 1;
    }
  }
  return List.unmodifiable(spreads);
}

/// 先保留完整显示页身份；身份失效时定位同一原图/半页。
int comicPageSpreadTarget(
  List<ComicPageSpread> spreads,
  int imageIndex,
  ComicPageSlice slice, {
  ComicPageSpread? previous,
}) {
  final retained = previous == null ? -1 : spreads.indexOf(previous);
  if (retained >= 0) return retained;
  final slot = (imageIndex: imageIndex, slice: slice);
  final exact = spreads.indexWhere((spread) => spread.slots.contains(slot));
  return exact >= 0
      ? exact
      : spreads.indexWhere(
          (spread) => spread.slots.any((slot) => slot.imageIndex == imageIndex),
        );
}
