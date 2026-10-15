import 'package:flutter_legado/src/domain/models/reader_interaction_settings.dart';
import 'package:flutter_legado/src/widgets/reader/reader_tap_hit_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

/// 九宫格命中保留原行为，配置不依赖Flutter坐标。
void main() {
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
      final config = ReaderInteractionSettings();
      for (var row = 0; row < 3; row++) {
        for (var column = 0; column < 3; column++) {
          expect(
            readerTapActionForPosition(
              config,
              Offset(column * 100 + 50, row * 200 + 100),
              const Size(300, 600),
            ),
            defaults[row * 3 + column],
          );
        }
      }
      expect(
        readerTapActionForPosition(
          config,
          const Offset(99.9, 200),
          const Size(300, 600),
        ),
        TapAction.prevPage,
      );
      expect(
        readerTapActionForPosition(
          config,
          const Offset(100, 200),
          const Size(300, 600),
        ),
        TapAction.toggleControls,
      );
      expect(
        readerTapActionForPosition(
          config,
          const Offset(200, 200),
          const Size(300, 600),
        ),
        TapAction.nextPage,
      );
    });

    test('正文外点击忽略，边缘防误触不会吞掉窄窗口的中心', () {
      final config = ReaderInteractionSettings(pageTouchClick: 399);
      for (final point in [
        const Offset(-1, 10),
        const Offset(50, -1),
        const Offset(300, 10),
        const Offset(50, 600),
        const Offset(double.nan, 10),
      ]) {
        expect(
          readerTapActionForPosition(config, point, const Size(300, 600)),
          TapAction.none,
        );
      }
      expect(
        readerTapActionForPosition(config, const Offset(50, 300), Size.zero),
        TapAction.none,
      );
      expect(
        readerTapActionForPosition(
          config,
          const Offset(0, 300),
          const Size(100, 600),
        ),
        TapAction.none,
      );
      expect(
        readerTapActionForPosition(
          config,
          const Offset(50, 300),
          const Size(100, 600),
        ),
        TapAction.toggleControls,
      );
    });
  });
}
