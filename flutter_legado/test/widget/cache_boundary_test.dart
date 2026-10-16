import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'dart:async';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/cache_provider.dart';
import 'package:flutter_legado/src/screens/cache_settings_screen.dart';
import 'package:flutter_legado/src/screens/other_settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/home_settings_storage.dart';
import '../mocks/mocks.dart';

void main() {
  late CacheRepositoryMock repository;
  late DatabaseMaintenanceServiceMock maintenance;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'sameTitleRemoved_book_1': true,
      '其他设置': '保留',
    });
    repository = CacheRepositoryMock();
    maintenance = DatabaseMaintenanceServiceMock();
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

  Future<void> openOther(WidgetTester tester) async {
    final settings = AppSettingsService(
      storages: {SettingsStorageKind.preferences: HomeSettingsStorage()},
    );
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        appSettingsServiceProvider.overrideWithValue(settings),
        cacheRepositoryProvider.overrideWithValue(repository),
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
        child: const MaterialApp(home: OtherSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('其他设置取消缓存清理与压缩不调用后端', (tester) async {
    await openOther(tester);
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
    testWidgets('其他设置通过窄仓储清理，失败=$fail', (tester) async {
      when(() => repository.clearCache()).thenAnswer((_) async {
        if (fail) throw StateError('拒绝清理');
      });
      await openOther(tester);
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
    testWidgets('其他设置压缩结果$result不误报成功', (tester) async {
      when(() => maintenance.shrinkDatabase()).thenAnswer((_) async {
        if (result == null) throw StateError('压缩失败');
        return result;
      });
      await openOther(tester);
      await tester.tap(find.text('压缩数据库'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();
      verify(() => maintenance.shrinkDatabase()).called(1);
      final expected = switch (result) {
        0 => '无需压缩或压缩失败',
        null => '压缩失败:',
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
