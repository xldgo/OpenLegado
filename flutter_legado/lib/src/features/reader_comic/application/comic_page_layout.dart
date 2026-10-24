/// 显示页与原图分离；取自参考版MangaPageSpread的单图/左右半页语义。— Codex + UI
enum ComicPageSlice { full, left, right }

typedef ComicPageSlot = ({int imageIndex, ComicPageSlice slice});

List<ComicPageSlot> buildComicPageSlots({
  required int imageCount,
  required Set<int> wideImages,
  required bool splitWidePages,
  required bool rightToLeft,
}) => List.unmodifiable([
  for (var index = 0; index < imageCount; index++)
    if (splitWidePages && wideImages.contains(index)) ...[
      (
        imageIndex: index,
        slice: rightToLeft ? ComicPageSlice.right : ComicPageSlice.left,
      ),
      (
        imageIndex: index,
        slice: rightToLeft ? ComicPageSlice.left : ComicPageSlice.right,
      ),
    ] else
      (imageIndex: index, slice: ComicPageSlice.full),
]);

/// 尺寸迟到或显示规则变化后，先保留半页，无法保留时按原图定位。
int comicPageSlotTarget(
  List<ComicPageSlot> slots,
  int imageIndex,
  ComicPageSlice slice,
) {
  final retained = slots.indexOf((imageIndex: imageIndex, slice: slice));
  return retained >= 0
      ? retained
      : slots.indexWhere((slot) => slot.imageIndex == imageIndex);
}
