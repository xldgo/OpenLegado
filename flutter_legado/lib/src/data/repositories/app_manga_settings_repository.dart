import '../../models/manga_scroll_mode.dart';
import '../../models/manga_auto_read.dart';
import '../../models/manga_page_scale_type.dart';
import '../../models/manga_click_actions.dart';
import '../../models/manga_config.dart';
import '../../domain/contracts/manga_settings_repository.dart';
import '../../domain/models/manga_settings.dart';
import '../services/app_settings_service.dart';
import '../settings/app_config_settings_repository.dart';

/// 投影共享设置服务，保持原键和默认值。— Codex + UI
class AppMangaSettingsRepository
    extends AppConfigSettingsRepository<MangaSettings>
    implements MangaSettingsRepository {
  AppMangaSettingsRepository(AppSettingsService service)
    : super(service, {
        'mangaColorFilter',
        'mangaFooterConfig',
        'enableMangaEInk',
        'enableMangaGray',
        'mangaEInkThreshold',
        'mangaScrollMode',
        'mangaAutoReadSpeed',
        'mangaPreDownloadNum',
        'mangaPageScaleType',
        'mangaSidePadding',
        'disableClickScroll',
        'disableMangaScale',
        'disableMangaPageAnim',
        'hideMangaTitle',
        'volumeKeyPage',
        'reverseVolumeKeyPage',
        'mangaLongClickSaveImage',
        'disableMangaCrossFade',
        'mangaBgColor',
        'mangaClickActions',
      });
  @override
  MangaSettings decode(Map<String, String?> values) => MangaSettings(
    colorFilter: MangaColorFilterConfig.fromStorage(values['mangaColorFilter']),
    footer: MangaFooterConfig.fromStorage(values['mangaFooterConfig']),
    enableEInk: values['enableMangaEInk'] == 'true',
    enableGray: values['enableMangaGray'] == 'true',
    eInkThreshold: int.tryParse(values['mangaEInkThreshold'] ?? '') ?? 150,
    scrollMode: MangaScrollModes.parse(values['mangaScrollMode']),
    autoReadSpeed: MangaAutoRead.parse(values['mangaAutoReadSpeed']),
    preloadImages:
        (int.tryParse(values['mangaPreDownloadNum'] ?? '') ?? 10) > 0,
    pageScaleType: MangaPageScaleType.parse(values['mangaPageScaleType']),
    sidePadding: (int.tryParse(values['mangaSidePadding'] ?? '') ?? 0).clamp(
      0,
      45,
    ),
    disableClickScroll: values['disableClickScroll'] == 'true',
    disableMangaScale: values['disableMangaScale'] == null
        ? true
        : values['disableMangaScale'] == 'true',
    disableMangaPageAnim: values['disableMangaPageAnim'] == 'true',
    hideMangaTitle: values['hideMangaTitle'] == 'true',
    volumeKeyPage: values['volumeKeyPage'] == null
        ? true
        : values['volumeKeyPage'] == 'true',
    reverseVolumeKeyPage: values['reverseVolumeKeyPage'] == 'true',
    longClickSaveImage: values['mangaLongClickSaveImage'] == null
        ? true
        : values['mangaLongClickSaveImage'] == 'true',
    disableCrossFade: values['disableMangaCrossFade'] == 'true',
    backgroundColor: MangaBgColors.parse(values['mangaBgColor']),
    clickActions: MangaClickActions.parse(values['mangaClickActions']),
  );
  @override
  Map<String, String> encode(MangaSettings value) => {
    'mangaColorFilter': value.colorFilter.toStorage(),
    'mangaFooterConfig': value.footer.toStorage(),
    'enableMangaEInk': value.enableEInk ? 'true' : 'false',
    'enableMangaGray': value.enableGray ? 'true' : 'false',
    'mangaEInkThreshold': value.eInkThreshold.toString(),
    'mangaScrollMode': value.scrollMode.toString(),
    'mangaAutoReadSpeed': value.autoReadSpeed.toString(),
    'mangaPreDownloadNum': value.preloadImages ? '10' : '0',
    'mangaPageScaleType': value.pageScaleType.toString(),
    'mangaSidePadding': value.sidePadding.toString(),
    'disableClickScroll': value.disableClickScroll ? 'true' : 'false',
    'disableMangaScale': value.disableMangaScale ? 'true' : 'false',
    'disableMangaPageAnim': value.disableMangaPageAnim ? 'true' : 'false',
    'hideMangaTitle': value.hideMangaTitle ? 'true' : 'false',
    'volumeKeyPage': value.volumeKeyPage ? 'true' : 'false',
    'reverseVolumeKeyPage': value.reverseVolumeKeyPage ? 'true' : 'false',
    'mangaLongClickSaveImage': value.longClickSaveImage ? 'true' : 'false',
    'disableMangaCrossFade': value.disableCrossFade ? 'true' : 'false',
    'mangaBgColor': value.backgroundColor.toString(),
    'mangaClickActions': MangaClickActions.serialize(value.clickActions),
  };
}
