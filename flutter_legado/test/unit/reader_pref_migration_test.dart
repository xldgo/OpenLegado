import 'package:flutter_legado/src/data/repositories/app_reader_settings_repository.dart';
import 'package:flutter_legado/src/models/reader_advanced_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/reader_settings_repository.dart';

/// 尚未迁移的点击区域存储与九宫格行为。
void main() {
  late AppReaderSettingsRepository repository;
  setUp(() => repository = createTestReaderSettingsRepository());
  TestWidgetsFlutterBinding.ensureInitialized();

  group('正文点击九宫格', () {
    const defaults = [
      TapAction.prevPage,
      TapAction.prevPage,
      TapAction.nextPage,
      TapAction.prevPage,
      TapAction.toggleControls,
      TapAction.nextPage,
      TapAction.prevPage,
      TapAction.nextPage,
      TapAction.nextPage,
    ];

    test('九格中心与分区边界执行对应动作', () {
      final config = ReaderAdvancedConfig();
      for (var row = 0; row < 3; row++) {
        for (var column = 0; column < 3; column++) {
          expect(
            config.actionForPosition(
              Offset(column * 100 + 50, row * 200 + 100),
              const Size(300, 600),
            ),
            defaults[row * 3 + column],
          );
        }
      }
      expect(
        config.actionForPosition(const Offset(99.9, 200), const Size(300, 600)),
        TapAction.prevPage,
      );
      expect(
        config.actionForPosition(const Offset(100, 200), const Size(300, 600)),
        TapAction.toggleControls,
      );
      expect(
        config.actionForPosition(const Offset(200, 200), const Size(300, 600)),
        TapAction.nextPage,
      );
    });

    test('正文外点击忽略，边缘防误触不会吞掉窄窗口的中心', () {
      final config = ReaderAdvancedConfig()..pageTouchClick = 399;
      for (final point in [
        const Offset(-1, 10),
        const Offset(50, -1),
        const Offset(300, 10),
        const Offset(50, 600),
        const Offset(double.nan, 10),
      ]) {
        expect(
          config.actionForPosition(point, const Size(300, 600)),
          TapAction.none,
        );
      }
      expect(
        config.actionForPosition(const Offset(50, 300), Size.zero),
        TapAction.none,
      );
      expect(
        config.actionForPosition(const Offset(0, 300), const Size(100, 600)),
        TapAction.none,
      );
      expect(
        config.actionForPosition(const Offset(50, 300), const Size(100, 600)),
        TapAction.toggleControls,
      );
    });

    test('旧默认三列采用新排列，自定义三列保留原动作', () async {
      SharedPreferences.setMockInitialValues({
        'reader_adv_left_action': TapAction.prevPage.index,
        'reader_adv_center_action': TapAction.toggleControls.index,
        'reader_adv_right_action': TapAction.nextPage.index,
      });
      expect((await repository.loadAdvanced()).tapActions, defaults);
      final columns = [
        TapAction.openCatalog,
        TapAction.none,
        TapAction.prevPage,
      ];
      SharedPreferences.setMockInitialValues({
        'reader_adv_left_action': columns[0].index,
        'reader_adv_center_action': columns[1].index,
        'reader_adv_right_action': columns[2].index,
      });
      expect((await repository.loadAdvanced()).tapActions, [
        ...columns,
        ...columns,
        ...columns,
      ]);
    });

    test('九格独立保存，复制不共享列表，损坏存储回退旧配置', () async {
      SharedPreferences.setMockInitialValues({});
      final config = ReaderAdvancedConfig();
      final copy = config.copy()..tapActions[0] = TapAction.openCatalog;
      expect(config.tapActions[0], TapAction.prevPage);
      await repository.saveAdvanced(copy);
      expect((await repository.loadAdvanced()).tapActions, [
        TapAction.openCatalog,
        ...defaults.skip(1),
      ]);
      final prefs = await SharedPreferences.getInstance();
      for (final invalid in [
        <String>['1'],
        List.filled(9, '99'),
        List.filled(9, 'not-an-action'),
      ]) {
        await prefs.setStringList('reader_adv_tap_actions_v1', invalid);
        expect((await repository.loadAdvanced()).tapActions, defaults);
      }
    });
  });
}
