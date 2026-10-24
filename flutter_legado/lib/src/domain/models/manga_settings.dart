import '../../models/manga_config.dart';

/// 漫画普通设置的类型化快照，存储键仅由数据层解释。— Codex + UI
enum MangaToggle {
  disableClickScroll,
  disableMangaScale,
  disableMangaPageAnim,
  hideMangaTitle,
  volumeKeyPage,
  reverseVolumeKeyPage,
  longClickSaveImage,
  disableCrossFade,
}

extension MangaSettingsToggle on MangaSettings {
  MangaSettings withToggle(
    MangaToggle option,
    bool enabled,
  ) => switch (option) {
    MangaToggle.disableClickScroll => copyWith(disableClickScroll: enabled),
    MangaToggle.disableMangaScale => copyWith(disableMangaScale: enabled),
    MangaToggle.disableMangaPageAnim => copyWith(disableMangaPageAnim: enabled),
    MangaToggle.hideMangaTitle => copyWith(hideMangaTitle: enabled),
    MangaToggle.volumeKeyPage => copyWith(volumeKeyPage: enabled),
    MangaToggle.reverseVolumeKeyPage => copyWith(reverseVolumeKeyPage: enabled),
    MangaToggle.longClickSaveImage => copyWith(longClickSaveImage: enabled),
    MangaToggle.disableCrossFade => copyWith(disableCrossFade: enabled),
  };
}

final class MangaSettings {
  const MangaSettings({
    required this.colorFilter,
    required this.footer,
    this.enableEInk = false,
    this.enableGray = false,
    this.eInkThreshold = 150,
    this.scrollMode = 4,
    this.autoReadSpeed = 3,
    this.preloadImages = true,
    this.autoOfflineCache = false,
    this.pageScaleType = 0,
    this.sidePadding = 0,
    this.disableClickScroll = false,
    this.disableMangaScale = true,
    this.disableMangaPageAnim = false,
    this.hideMangaTitle = false,
    this.volumeKeyPage = true,
    this.reverseVolumeKeyPage = false,
    this.longClickSaveImage = true,
    this.disableCrossFade = false,
    this.backgroundColor = 0xFF000000,
    required this.clickActions,
  });
  final MangaColorFilterConfig colorFilter;
  final MangaFooterConfig footer;
  final bool enableEInk;
  final bool enableGray;
  final int eInkThreshold;
  final int scrollMode;
  final int autoReadSpeed;
  final bool preloadImages;
  final bool autoOfflineCache;
  final int pageScaleType;
  final int sidePadding;
  final bool disableClickScroll;
  final bool disableMangaScale;
  final bool disableMangaPageAnim;
  final bool hideMangaTitle;
  final bool volumeKeyPage;
  final bool reverseVolumeKeyPage;
  final bool longClickSaveImage;
  final bool disableCrossFade;
  final int backgroundColor;
  final List<int> clickActions;
  MangaSettings copyWith({
    MangaColorFilterConfig? colorFilter,
    MangaFooterConfig? footer,
    bool? enableEInk,
    bool? enableGray,
    int? eInkThreshold,
    int? scrollMode,
    int? autoReadSpeed,
    bool? preloadImages,
    bool? autoOfflineCache,
    int? pageScaleType,
    int? sidePadding,
    bool? disableClickScroll,
    bool? disableMangaScale,
    bool? disableMangaPageAnim,
    bool? hideMangaTitle,
    bool? volumeKeyPage,
    bool? reverseVolumeKeyPage,
    bool? longClickSaveImage,
    bool? disableCrossFade,
    int? backgroundColor,
    List<int>? clickActions,
  }) => MangaSettings(
    colorFilter: colorFilter ?? this.colorFilter,
    footer: footer ?? this.footer,
    enableEInk: enableEInk ?? this.enableEInk,
    enableGray: enableGray ?? this.enableGray,
    eInkThreshold: eInkThreshold ?? this.eInkThreshold,
    scrollMode: scrollMode ?? this.scrollMode,
    autoReadSpeed: autoReadSpeed ?? this.autoReadSpeed,
    preloadImages: preloadImages ?? this.preloadImages,
    autoOfflineCache: autoOfflineCache ?? this.autoOfflineCache,
    pageScaleType: pageScaleType ?? this.pageScaleType,
    sidePadding: sidePadding ?? this.sidePadding,
    disableClickScroll: disableClickScroll ?? this.disableClickScroll,
    disableMangaScale: disableMangaScale ?? this.disableMangaScale,
    disableMangaPageAnim: disableMangaPageAnim ?? this.disableMangaPageAnim,
    hideMangaTitle: hideMangaTitle ?? this.hideMangaTitle,
    volumeKeyPage: volumeKeyPage ?? this.volumeKeyPage,
    reverseVolumeKeyPage: reverseVolumeKeyPage ?? this.reverseVolumeKeyPage,
    longClickSaveImage: longClickSaveImage ?? this.longClickSaveImage,
    disableCrossFade: disableCrossFade ?? this.disableCrossFade,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    clickActions: clickActions ?? this.clickActions,
  );
}
