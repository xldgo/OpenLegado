import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/contracts/cover_cache_repository.dart';
import 'package:flutter_legado/src/features/cache/application/download_cache_settings.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/cache_provider.dart';
import 'package:flutter_legado/src/features/cache/presentation/cache_settings_screen.dart';
import 'package:flutter_legado/src/features/cache/presentation/download_cache_settings_screen.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

import '../mocks/mocks.dart';

class _CoverCache extends Mock implements CoverCacheRepository {}

void main() {
  late CacheRepositoryMock repository;
  late DatabaseMaintenanceServiceMock maintenance;
  late _CoverCache coverCache;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'sameTitleRemoved_book_1': true,
      '其他设置': '保留',
    });
    repository = CacheRepositoryMock();
    maintenance = DatabaseMaintenanceServiceMock();
    coverCache = _CoverCache();
    when(() => coverCache.getSize()).thenAnswer((_) async => 2048);
    when(() => coverCache.clear()).thenAnswer((_) async {});
    when(() => repository.getCacheSize()).thenAnswer((_) async => 5242880);
    when(() => repository.getCacheBookCount()).thenAnswer((_) async => 2);
    when(() => repository.getCacheChapterCount()).thenAnswer((_) async => 26);
  });

  Future<void> openCache(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cacheRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: CacheSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirmClear(WidgetTester tester) async {
    await tester.ensureVisible(find.text('清除全部缓存'));
    await tester.tap(find.text('清除全部缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
  }

  testWidgets('真实缓存页显示统计，取消不清理，确认后更新统计与章级标记', (tester) async {
    var cleared = false;
    when(() => repository.getCacheSize())
        .thenAnswer((_) async => cleared ? 0 : 5242880);
    when(() => repository.getCacheBookCount())
        .thenAnswer((_) async => cleared ? 0 : 2);
    when(() => repository.getCacheChapterCount())
        .thenAnswer((_) async => cleared ? 0 : 26);
    when(() => repository.clearCache()).thenAnswer((_) async {
      cleared = true;
    });
    await openCache(tester);
    expect(find.text('5.0 MB'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    await tester.ensureVisible(find.text('清除全部缓存'));
    await tester.tap(find.text('清除全部缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.clearCache());
    await confirmClear(tester);
    verify(() => repository.clearCache()).called(1);
    expect(find.text('已清除 5.0 MB 缓存'), findsOneWidget);
    expect(find.text('0 B'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('sameTitleRemoved_book_1'), isFalse);
    expect(prefs.getString('其他设置'), '保留');
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计读取失败不显示假零值，重试恢复真实统计', (tester) async {
    when(() => repository.getCacheSize()).thenThrow(StateError('读取失败'));
    await openCache(tester);
    expect(find.textContaining('缓存统计读取失败'), findsOneWidget);
    expect(find.text('0 B'), findsNothing);
    expect(find.text('0'), findsNothing);
    when(() => repository.getCacheSize()).thenAnswer((_) async => 5242880);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.textContaining('缓存统计读取失败'), findsNothing);
    expect(find.text('5.0 MB'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('清理失败不报成功，也不提前复位章级镜像', (tester) async {
    when(() => repository.clearCache()).thenThrow(StateError('拒绝清理'));
    await openCache(tester);
    await confirmClear(tester);
    expect(find.textContaining('清除缓存失败'), findsOneWidget);
    expect(find.textContaining('已清除'), findsNothing);
    expect(find.text('5.0 MB'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'sameTitleRemoved_book_1',
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('清理后刷新失败保留最近成功统计并允许重试', (tester) async {
    when(() => repository.clearCache()).thenAnswer((_) async {
      when(() => repository.getCacheBookCount()).thenThrow(StateError('刷新失败'));
    });
    await openCache(tester);
    await confirmClear(tester);
    expect(find.textContaining('缓存统计读取失败'), findsOneWidget);
    expect(find.text('5.0 MB'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    when(() => repository.getCacheBookCount()).thenAnswer((_) async => 1);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('缓存统计读取失败'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  Future<void> openDownloads(WidgetTester tester) async {
    final settings = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        appSettingsServiceProvider.overrideWithValue(settings),
        cacheRepositoryProvider.overrideWithValue(repository),
        coverCacheRepositoryProvider.overrideWithValue(coverCache),
        databaseMaintenanceServiceProvider.overrideWithValue(maintenance),
      ]),
    );
    addTearDown(() {
      container.dispose();
      unawaited(settings.dispose());
    });
    tester.view.physicalSize = const Size(1000, 10000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DownloadCacheSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('封面缓存显示真实统计，取消不删除，确认后重新读取', (tester) async {
    var cleared = false;
    when(() => coverCache.getSize())
        .thenAnswer((_) async => cleared ? 0 : 2048);
    when(() => coverCache.clear()).thenAnswer((_) async => cleared = true);
    await openDownloads(tester);
    expect(find.text('2.0 KB'), findsOneWidget);
    await tester.tap(find.text('封面缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    verifyNever(() => coverCache.clear());
    await tester.tap(find.text('封面缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清理'));
    await tester.pumpAndSettle();
    verify(() => coverCache.clear()).called(1);
    expect(find.text('0 B'), findsOneWidget);
    expect(find.text('封面缓存已清理'), findsOneWidget);
    verifyNever(() => repository.clearCache());
    expect(tester.takeException(), isNull);
  });

  testWidgets('封面统计失败可重试，清理失败不伪报成功或归零', (tester) async {
    when(() => coverCache.getSize()).thenThrow(StateError('读取失败'));
    await openDownloads(tester);
    expect(find.text('缓存统计读取失败，点按重试'), findsOneWidget);
    expect(find.text('0 B'), findsNothing);
    when(() => coverCache.getSize()).thenAnswer((_) async => 2048);
    await tester.tap(find.text('封面缓存'));
    await tester.pumpAndSettle();
    expect(find.text('2.0 KB'), findsOneWidget);
    when(() => coverCache.clear()).thenThrow(StateError('清理失败'));
    await tester.tap(find.text('封面缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清理'));
    await tester.pumpAndSettle();
    expect(find.text('封面缓存清理失败，请重试'), findsOneWidget);
    expect(find.text('封面缓存已清理'), findsNothing);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('封面清理期间维护互斥，离页后结果不访问已释放界面', (tester) async {
    final gate = Completer<void>();
    when(() => coverCache.clear()).thenAnswer((_) => gate.future);
    await openDownloads(tester);
    await tester.tap(find.text('封面缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清理'));
    await tester.pumpAndSettle();
    for (final title in ['封面缓存', '清理缓存', '压缩数据库']) {
      final tile = tester.widget<SettingTile>(
        find.widgetWithText(SettingTile, title),
      );
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
    }
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('下载设置按上游分组展示旧偏好，未接线项不产生写入', (tester) async {
    SharedPreferences.setMockInitialValues({
      'bitmapCacheSize': 128,
      'imageRetainNum': 9,
      'preDownloadNum': 30,
      'userAgent': '原有代理',
    });
    await openDownloads(tester);
    final groups = tester.widgetList<SettingsGroup>(find.byType(SettingsGroup));
    expect(groups.map((group) => group.title), [
      'HTTP 缓存',
      '下载设置',
      '图片缓存',
      '网络设置',
      '其他',
    ]);
    final disabled = tester
        .widgetList<SettingTile>(find.byType(SettingTile))
        .where((tile) => !tile.enabled)
        .toList();
    expect(disabled, hasLength(4));
    for (final title in ['漫画缓存']) {
      final tile = disabled.singleWhere((tile) => tile.title == title);
      expect(tile.subtitle, '待实现');
      expect(tile.value, isNull);
      expect(tile.onTap, isNull);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('当前最大缓存 128 MB\n待实现'), findsOneWidget);
    expect(find.text('保留已读章节数量 9\n待实现'), findsOneWidget);
    final preload = tester.widget<SettingTile>(
      find.widgetWithText(SettingTile, '向后预下载'),
    );
    expect(preload.value, '30');
    expect(preload.enabled, isTrue);
    expect(find.text('原有代理\n待实现'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getInt('bitmapCacheSize'),
      128,
    );
    verifyNever(() => repository.clearCache());
    verifyNever(() => maintenance.shrinkDatabase());
  });

  testWidgets('下载设置清理期间禁用维护操作，离页后不发布迟到提示', (tester) async {
    final gate = Completer<void>();
    when(() => repository.clearCache()).thenAnswer((_) => gate.future);
    await openDownloads(tester);
    await tester.tap(find.text('清理缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清理'));
    await tester.pumpAndSettle();
    final shrink = tester.widget<SettingTile>(
      find.ancestor(of: find.text('压缩数据库'), matching: find.byType(SettingTile)),
    );
    expect(shrink.enabled, isFalse);
    expect(shrink.onTap, isNull);
    verify(() => repository.clearCache()).called(1);
    verifyNever(() => maintenance.shrinkDatabase());
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('前后预下载数字编辑支持关闭、取消和边界，分别持久化', (tester) async {
    SharedPreferences.setMockInitialValues({
      'preDownloadNum': 6,
      'preDownloadNumPrev': 2,
    });
    await openDownloads(tester);
    final prefs = await SharedPreferences.getInstance();
    for (final (title, key, initial, saved) in [
      ('向后预下载', 'preDownloadNum', '6', '0'),
      ('向前预下载', 'preDownloadNumPrev', '2', '100'),
    ]) {
      final label = find.text(title);
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, initial), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      await tester.enterText(find.byType(TextField), '50');
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(prefs.getInt(key), int.parse(initial));
      await tester.tap(label);
      await tester.pumpAndSettle();
      for (final invalid in ['-1', '101']) {
        await tester.enterText(find.byType(TextField), invalid);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(find.text('请输入 0～100 之间的整数'), findsOneWidget);
        expect(prefs.getInt(key), int.parse(initial));
      }
      await tester.enterText(find.byType(TextField), saved);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(prefs.getInt(key), int.parse(saved));
      expect(
        tester
            .widget<SettingTile>(find.widgetWithText(SettingTile, title))
            .value,
        saved,
      );
    }
    expect(prefs.getInt('preDownloadNum'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('下载设置取消缓存清理与压缩不调用后端', (tester) async {
    await openDownloads(tester);
    for (final title in ['清理缓存', '压缩数据库']) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    }
    verifyNever(() => repository.clearCache());
    verifyNever(() => maintenance.shrinkDatabase());
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    testWidgets('下载设置通过窄仓储清理，失败=$fail', (tester) async {
      when(() => repository.clearCache()).thenAnswer((_) async {
        if (fail) throw StateError('拒绝清理');
      });
      await openDownloads(tester);
      await tester.tap(find.text('清理缓存'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '清理'));
      await tester.pumpAndSettle();
      verify(() => repository.clearCache()).called(1);
      expect(find.text('成功清理缓存'), fail ? findsNothing : findsOneWidget);
      expect(find.textContaining('清理失败'), fail ? findsOneWidget : findsNothing);
      verifyNever(() => maintenance.shrinkDatabase());
      expect(tester.takeException(), isNull);
    });
  }

  for (final result in [0, 10485760, null]) {
    testWidgets('下载设置压缩结果$result不误报成功', (tester) async {
      when(() => maintenance.shrinkDatabase()).thenAnswer((_) async {
        if (result == null) throw StateError('压缩失败');
        return result;
      });
      await openDownloads(tester);
      await tester.tap(find.text('压缩数据库'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();
      verify(() => maintenance.shrinkDatabase()).called(1);
      final expected = switch (result) {
        0 => '无需压缩或压缩失败',
        null => '压缩失败：',
        _ => '压缩完成，释放 10.0 MB',
      };
      expect(find.textContaining(expected), findsOneWidget);
      if (result == null || result == 0) {
        expect(find.textContaining('压缩完成'), findsNothing);
      }
      verifyNever(() => repository.clearCache());
      expect(tester.takeException(), isNull);
    });
  }
}
