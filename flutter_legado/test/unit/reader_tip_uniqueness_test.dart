import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/reader_page_layout_settings.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late AppReaderSettingsRepository repository;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage();
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    repository = AppReaderSettingsRepository(service);
  });
  tearDown(() => service.dispose());
  List<int> slots() {
    final page = repository.current.pageLayout;
    return [
      page.header.leftTip,
      page.header.middleTip,
      page.header.rightTip,
      page.footer.leftTip,
      page.footer.middleTip,
      page.footer.rightTip,
    ];
  }

  test('默认时间从页眉移至页脚，只清除同类原位置', () async {
    await repository.updatePageEdge(ReaderPageEdge.footer, rightTip: 2);
    expect(slots(), [0, 0, 3, 7, 0, 2]);
    expect(storage.values['reader_header_tip_left'], 0);
    expect(storage.values['reader_footer_tip_right'], 2);
  });

  test('首次未load先读六槽，按实际设置移动提示', () async {
    storage.values['reader_header_tip_middle'] = 1;
    await repository.updatePageEdge(ReaderPageEdge.footer, leftTip: 1);
    expect(slots(), [2, 0, 3, 1, 0, 6]);
  });

  test('清空只影响目标，空选项不互斥', () async {
    await repository.updatePageEdge(
      ReaderPageEdge.header,
      leftTip: 0,
      middleTip: 0,
    );
    expect(slots(), [0, 0, 3, 7, 0, 6]);
    expect(storage.writes.map((e) => e.$1).toSet(), {
      'reader_header_tip_left',
      'reader_header_tip_middle',
    });
  });

  test('多个显式槽位按左中右应用，最后选择生效', () async {
    await repository.updatePageEdge(
      ReaderPageEdge.header,
      leftTip: 3,
      middleTip: 3,
      rightTip: 3,
    );
    expect(slots(), [0, 0, 3, 7, 0, 6]);
  });

  test('快速连续选择读取乐观快照，不留下两个相同提示', () async {
    await repository.load();
    final barrier = Completer<void>();
    final entered = Completer<void>();
    storage.beforeWrite = (_, _) async {
      if (!entered.isCompleted) entered.complete();
      await barrier.future;
    };
    final first = repository.updatePageEdge(
      ReaderPageEdge.header,
      middleTip: 2,
    );
    await entered.future;
    final second = repository.updatePageEdge(
      ReaderPageEdge.footer,
      rightTip: 2,
    );
    await Future<void>.delayed(Duration.zero);
    expect(slots(), [0, 0, 3, 7, 0, 2]);
    barrier.complete();
    await Future.wait([first, second]);
    await repository.reload();
    expect(slots(), [0, 0, 3, 7, 0, 2]);
  });

  test('读取失败不写入，保存失败原选择回退且可重试', () async {
    storage.readFailure = true;
    await expectLater(
      repository.updatePageEdge(ReaderPageEdge.header, rightTip: 7),
      throwsStateError,
    );
    expect(storage.writes, isEmpty);
    storage.readFailure = false;
    await repository.load();
    storage.writeFailure = true;
    await expectLater(
      repository.updatePageEdge(ReaderPageEdge.header, rightTip: 7),
      throwsStateError,
    );
    expect(slots(), [2, 0, 3, 7, 0, 6]);
    storage.writeFailure = false;
    await repository.updatePageEdge(ReaderPageEdge.header, rightTip: 7);
    expect(slots(), [2, 0, 7, 0, 0, 6]);
  });

  test('真实Preferences重建后保留移动结果和其他设置', () async {
    final actualService = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(actualService.dispose);
    final actual = AppReaderSettingsRepository(actualService);
    await actual.updatePageEdge(ReaderPageEdge.footer, middleTip: 2);
    await actual.updateScreen(hideStatusBar: true);
    final fresh = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(fresh.dispose);
    final restored = await AppReaderSettingsRepository(fresh).load();
    expect(restored.pageLayout.header.leftTip, 0);
    expect(restored.pageLayout.footer.middleTip, 2);
    expect(restored.screen.hideStatusBar, isTrue);
  });

  test('非提示更新不整理其他槽位，相关显示与边距保持', () async {
    storage.values.addAll({
      'reader_header_tip_left': 1,
      'reader_footer_tip_middle': 1,
    });
    await repository.load();
    final before = slots();
    await repository.updatePageEdge(ReaderPageEdge.footer, mode: 1, top: 9);
    expect(slots(), before);
    expect(storage.writes.map((e) => e.$1).toSet(), {
      'reader_footer_mode',
      'reader_footer_padding_top',
    });
  });
}
