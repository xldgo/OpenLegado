import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/app/bootstrap/app_settings_factory.dart';
import 'package:flutter_legado/src/data/repositories/app_manga_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_config_repository.dart';
import 'package:flutter_legado/src/domain/models/manga_settings.dart';
import 'package:flutter_legado/src/features/reader_comic/application/comic_settings_controller.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../../../fixtures/config_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockConfigRepository config;
  late AppMangaSettingsRepository repository;
  late ComicSettingsController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    config = MockConfigRepository(
      values: {'mangaScrollMode': '2', 'mangaSidePadding': '8'},
    );
    final service = createAppSettingsService(configRepository: () => config);
    addTearDown(service.dispose);
    repository = AppMangaSettingsRepository(service);
    controller = ComicSettingsController(repository);
    addTearDown(controller.dispose);
  });

  test('加载统一快照，未覆盖时跟随全局', () async {
    expect(controller.current.scrollMode, 4);
    await controller.load();
    expect(controller.scrollMode(null), 2);
    expect(controller.sidePadding(null), 8);
    expect(controller.current.volumeKeyPage, true);
    expect(controller.current.longClickSaveImage, true);
  });

  test('书级覆盖优先，非法模式回退全局，留白按原范围裁剪', () async {
    await controller.load();
    const book = ReadConfig(mangaScrollMode: 3, webtoonSidePaddingDp: 0);
    expect(controller.scrollMode(book), 3);
    expect(controller.sidePadding(book), 0);
    await controller.setScrollMode(5);
    await controller.setSidePadding(25);
    expect(controller.scrollMode(book), 3);
    expect(controller.sidePadding(book), 0);
    expect(controller.scrollMode(const ReadConfig(mangaScrollMode: 99)), 5);
    expect(
      controller.sidePadding(const ReadConfig(webtoonSidePaddingDp: 90)),
      45,
    );
    expect(controller.scrollMode(null), 5);
    expect(controller.sidePadding(null), 25);
  });

  test('更新立即通知，连续不同字段保存不覆盖彼此或其他设置', () async {
    await controller.load();
    var notifications = 0;
    controller.addListener(() => notifications++);
    final speed = controller.setAutoReadSpeed(10);
    expect(controller.current.autoReadSpeed, 10);
    final toggle = controller.setToggle(MangaToggle.hideMangaTitle, true);
    expect(controller.current.hideMangaTitle, true);
    await Future.wait([speed, toggle]);
    expect(notifications, 2);
    expect(repository.current.autoReadSpeed, 10);
    expect(repository.current.hideMangaTitle, true);
    expect(repository.current.scrollMode, 2);
    expect(await config.getConfig('mangaAutoReadSpeed'), '10');
    expect(await config.getConfig('hideMangaTitle'), 'true');
  });

  test('电子纸与灰度互斥，关闭一方不修改另一方', () async {
    await controller.load();
    await controller.setGray(true);
    expect(controller.current.enableGray, true);
    await controller.setEInk(true);
    expect(controller.current.enableGray, false);
    expect(controller.current.enableEInk, true);
    await controller.setGray(false);
    expect(controller.current.enableEInk, true);
    await controller.setGray(true);
    expect(controller.current.enableEInk, false);
    expect(repository.current.enableGray, true);
  });

  test('模式、留白、速度、阈值与适配类型保持原归一规则', () async {
    await controller.load();
    await controller.setScrollMode(99);
    await controller.setSidePadding(99);
    await controller.setAutoReadSpeed(0);
    await controller.setPageScaleType(99);
    await controller.setWidePageMode(99);
    await controller.setThreshold(-5);
    expect(controller.current.scrollMode, 4);
    expect(controller.current.sidePadding, 45);
    expect(controller.current.autoReadSpeed, 1);
    expect(controller.current.pageScaleType, 0);
    expect(controller.current.widePageMode, 0);
    await controller.setWidePageMode(3);
    await repository.reload();
    expect(repository.current.widePageMode, 3);
    expect(controller.current.eInkThreshold, 0);
  });

  test('所有行为开关都经同一快照保存', () async {
    await controller.load();
    for (final option in MangaToggle.values) {
      await controller.setToggle(option, true);
    }
    expect(repository.current.disableClickScroll, true);
    expect(repository.current.disableMangaScale, true);
    expect(repository.current.disableMangaPageAnim, true);
    expect(repository.current.hideMangaTitle, true);
    expect(repository.current.volumeKeyPage, true);
    expect(repository.current.reverseVolumeKeyPage, true);
    expect(repository.current.longClickSaveImage, true);
    expect(repository.current.disableCrossFade, true);
  });

  test('滤镜和页脚复制面板参数，后续修改原对象不污染已保存值', () async {
    await controller.load();
    final filter = MangaColorFilterConfig(r: 10, l: 80);
    final footer = MangaFooterConfig(hideFooter: true);
    await controller.setColorFilter(filter);
    await controller.setFooter(footer);
    filter.r = 100;
    footer.hideFooter = false;
    expect(controller.current.colorFilter.r, 10);
    expect(controller.current.colorFilter.l, 80);
    expect(controller.current.footer.hideFooter, true);
    expect(repository.current.colorFilter.r, 10);
    expect(repository.current.footer.hideFooter, true);
  });

  test('点击动作只更新指定格，非法索引及背景值不写入', () async {
    await controller.load();
    final before = List.of(controller.current.clickActions);
    await controller.cycleClickAction(0);
    expect(controller.current.clickActions[0], 0);
    expect(controller.current.clickActions.skip(1), before.skip(1));
    expect(
      () => controller.current.clickActions.clear(),
      throwsUnsupportedError,
    );
    await controller.cycleClickAction(-1);
    await controller.cycleClickAction(99);
    await controller.setBackground(-1);
    expect(controller.current.backgroundColor, 0xFF000000);
    await controller.setBackground(0xFF123456);
    expect(repository.current.backgroundColor, 0xFF123456);
  });

  test('保存失败保留页面即时显示，存储不伪装成功，后续可以重试', () async {
    var fail = true;
    final storage = TestConfigRepository(
      read: (_) async => null,
      write: (_, _) async {
        if (fail) throw StateError('不能保存');
      },
    );
    final service = createAppSettingsService(configRepository: () => storage);
    addTearDown(service.dispose);
    final stored = AppMangaSettingsRepository(service);
    final local = ComicSettingsController(stored);
    addTearDown(local.dispose);
    await local.load();
    await local.setSidePadding(12);
    expect(local.current.sidePadding, 12);
    expect(stored.current.sidePadding, 0);
    fail = false;
    await local.setSidePadding(12);
    expect(stored.current.sidePadding, 12);
  });
  test('预载开关保存失败不改变状态，成功后重读图片和自动离线配置', () async {
    var fail = true;
    final values = <String, String>{};
    final storage = TestConfigRepository(
      read: (key) async => values[key],
      write: (key, value) async {
        if (fail) throw StateError('写入失败');
        values[key] = value;
      },
    );
    final service = createAppSettingsService(configRepository: () => storage);
    addTearDown(service.dispose);
    final repository = AppMangaSettingsRepository(service);
    final subject = ComicSettingsController(repository);
    addTearDown(subject.dispose);
    await subject.load();
    await expectLater(subject.setPreloadImages(false), throwsStateError);
    await expectLater(subject.setAutoOfflineCache(true), throwsStateError);
    expect(subject.current.autoOfflineCache, isFalse);
    expect(repository.current.autoOfflineCache, isFalse);
    expect(subject.current.preloadImages, isTrue);
    expect(repository.current.preloadImages, isTrue);
    fail = false;
    await subject.setPreloadImages(false);
    expect(subject.current.preloadImages, isFalse);
    expect(values['mangaPreDownloadNum'], '0');
    await subject.setAutoOfflineCache(true);
    expect(subject.current.autoOfflineCache, isTrue);
    expect(values['mangaAutoOfflineCache'], 'true');
    await repository.reload();
    expect(repository.current.preloadImages, isFalse);
    expect(repository.current.autoOfflineCache, isTrue);
  });
}
