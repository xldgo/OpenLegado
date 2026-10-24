import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_style_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/page_turn_mode.dart';
import 'package:flutter_legado/src/domain/models/reader_style.dart';
import 'package:flutter_legado/src/domain/models/reader_page_layout_settings.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late AppReaderSettingsRepository settings;
  late AppReaderStyleRepository styles;

  setUp(() async {
    storage = HomeSettingsStorage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    settings = AppReaderSettingsRepository(service);
    styles = AppReaderStyleRepository(service);
    await settings.load();
    await styles.load();
  });
  tearDown(() => service.dispose());

  test('微信预设默认单位一致，可编辑并恢复，副本与共享布局独立', () async {
    final data = jsonDecode(
      File('test/fixtures/upstream_reader_colors.json').readAsStringSync(),
    ) as Map;
    final preset = (data['styles'] as List).first as Map;
    await styles.select('wechat');
    expect(settings.current.fontSize, 20);
    await styles.setShareLayout(false);
    expect(settings.current.fontSize, preset['textSize']);
    expect(
      settings.current.lineHeight,
      (preset['lineSpacingExtra'] as num) / 10,
    );
    expect(
      settings.current.textLayout.paragraphSpacing,
      preset['paragraphSpacing'],
    );
    expect(
      settings.current.pageLayout.bodyPadding,
      ReaderPagePadding(
        top: (preset['paddingTop'] as num).toDouble(),
        bottom: (preset['paddingBottom'] as num).toDouble(),
        left: (preset['paddingLeft'] as num).toDouble(),
        right: (preset['paddingRight'] as num).toDouble(),
      ),
    );
    expect(
      settings.current.pageLayout.header,
      ReaderPageEdgeSettings(
        padding: ReaderPagePadding(
          top: (preset['headerPaddingTop'] as num).toDouble(),
          bottom: (preset['headerPaddingBottom'] as num).toDouble(),
          left: (preset['headerPaddingLeft'] as num).toDouble(),
          right: (preset['headerPaddingRight'] as num).toDouble(),
        ),
        showLine: preset['showHeaderLine'] as bool,
        leftTip: preset['tipHeaderLeft'] as int,
        middleTip: preset['tipHeaderMiddle'] as int,
        rightTip: preset['tipHeaderRight'] as int,
      ),
    );
    await settings.update(fontSize: 27);
    await styles.updateColors(
      isNight: false,
      update: (_) => const ReaderColors(background: 0xFF112233),
    );
    await styles.select('preset2');
    await styles.select('wechat');
    expect(settings.current.fontSize, 27);
    expect(styles.current.selected.day.background, 0xFF112233);
    await styles.restorePreset('wechat');
    expect(settings.current.fontSize, 24);
    expect(styles.current.selected.day, readerStylePresets.first.day);
    final copy = await styles.createFromTemplate('wechat', '我的微信样式');
    await settings.update(fontSize: 27);
    await styles.setShareLayout(true);
    expect(settings.current.fontSize, 20);
    await styles.setShareLayout(false);
    await styles.reload();
    expect(settings.current.fontSize, 27);
    await styles.select('preset2');
    expect(settings.current.fontSize, 20);
    await styles.select(copy);
    expect(settings.current.fontSize, 27);
    await styles.select('wechat');
    expect(settings.current.fontSize, 24);
    await styles.setShareLayout(true);
    await settings.update(fontSize: 22);
    storage.writeFailure = true;
    await expectLater(styles.restorePreset('wechat'), throwsStateError);
    expect(settings.current.fontSize, 22);
    storage.writeFailure = false;
    await styles.restorePreset('wechat');
    expect(styles.current.selectedId, 'wechat');
    expect(settings.current.fontSize, 24);
    await styles.setShareLayout(false);
    await styles.select(copy);
    expect(settings.current.fontSize, 27);
  });

  test('独立排版、共享切换及重新装配保留各自布局，全局偏好不随预设变化', () async {
    await settings.update(fontSize: 22, fontFamily: 'Custom_shared');
    await settings.updatePageLayout(left: 18);
    final styleA = await styles.createFromTemplate('custom', '样式甲');
    final styleB = await styles.createFromTemplate('custom', '样式乙');
    await styles.select(styleA);
    final updating = settings.update(
      fontSize: 26,
      fontFamily: '',
      pageTurnMode: PageTurnMode.slide,
    );
    final switching = styles.select(styleB);
    await Future.wait([updating, switching]);
    expect(settings.current.fontSize, 22);
    await styles.select(styleA);
    await settings.updateTextLayout(paragraphSpacing: 4, italic: true);
    await settings.updateTitle(mode: 1, size: 6);
    await settings.updatePageLayout(left: 30);
    await settings.update(showMenuLabels: true);
    final independent = settings.current;

    await styles.select(styleB);
    expect(settings.current.fontSize, 22);
    expect(settings.current.fontFamily, 'Custom_shared');
    expect(settings.current.pageLayout.bodyPadding.left, 18);
    expect(settings.current.showMenuLabels, isTrue);
    await styles.select(styleA);
    expect(settings.current, independent);
    expect(settings.current.fontFamily, isNull);

    await styles.setShareLayout(true);
    expect(settings.current.fontSize, 22);
    await settings.update(fontSize: 24);
    await styles.select(styleB);
    expect(settings.current.fontSize, 24);
    await styles.setShareLayout(false);
    expect(settings.current.fontSize, 22);
    await styles.select(styleA);
    expect(settings.current, independent);

    final fresh = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(fresh.dispose);
    final restoredSettings = AppReaderSettingsRepository(fresh);
    final restoredStyles = AppReaderStyleRepository(fresh);
    await restoredStyles.load();
    await restoredSettings.load();
    expect(restoredStyles.current.shareLayout, isFalse);
    expect(restoredSettings.current, independent);
  });

  test('先前失败的排版不混入后续保存，恢复文档后重新投影有效布局', () async {
    await settings.update(fontSize: 22);
    await styles.setShareLayout(false);
    final original = storage.values['reader_styles'];
    var failNext = true;
    storage.beforeWrite = (key, _) async {
      if (key == 'reader_styles' && failNext) {
        failNext = false;
        throw StateError('首个布局写入失败');
      }
    };
    final failed = settings.update(fontSize: 28);
    final saved = settings.updatePageLayout(left: 31);
    await Future.wait([expectLater(failed, throwsStateError), saved]);
    expect(settings.current.fontSize, 22);
    expect(settings.current.pageLayout.bodyPadding.left, 31);

    storage.values['reader_styles'] = original;
    await settings.reload();
    expect(settings.current.fontSize, 22);
    expect(settings.current.pageLayout.bodyPadding.left, 16);
    expect(styles.current.shareLayout, isFalse);
  });
}
