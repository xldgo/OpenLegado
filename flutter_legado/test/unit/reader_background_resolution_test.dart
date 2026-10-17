// 阅读背景遵循主题明暗和纯黑偏好，保留浅色预设及自定义配色。
// 越界索引回落默认背景；纯函数不依赖持久化或 WidgetsBinding。
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';

void main() {
  const custom = Color(0xFF232323);

  group('resolveReaderBackground 背景默认解析', () {
    test('深色默认随纯黑开关变化，并保持浅色文字', () {
      for (final amoled in [false, true]) {
        final resolved = resolveReaderBackground(
          themeBrightness: Brightness.dark,
          themeAmoled: amoled,
        );
        expect(
          resolved,
          amoled ? const Color(0xFF000000) : ReaderBackground.dark,
        );
        expect(
          ReaderState(backgroundColor: resolved).textColor,
          const Color(0xFFCCCCCC),
        );
      }
    });

    test('亮色主题 + 从未显式设置 → 白色（原默认不变）', () {
      final resolved = resolveReaderBackground(
        themeBrightness: Brightness.light,
        storedBgIndex: null,
        customBgColor: null,
      );
      expect(resolved, equals(ReaderBackground.white));
    });

    test('深色主题 + 显式预设索引 1 → 保留 green', () {
      final resolved = resolveReaderBackground(
        themeBrightness: Brightness.dark,
        themeAmoled: true,
        storedBgIndex: 1,
        customBgColor: null,
      );
      expect(resolved, equals(ReaderBackground.green));
    });

    test('夜间预设仅在软件深色且纯黑开启时使用纯黑', () {
      for (final brightness in Brightness.values) {
        for (final amoled in [false, true]) {
          final resolved = resolveReaderBackground(
            themeBrightness: brightness,
            themeAmoled: amoled,
            storedBgIndex: 4,
          );
          expect(
            resolved,
            brightness == Brightness.dark && amoled
                ? const Color(0xFF000000)
                : ReaderBackground.dark,
          );
        }
      }
    });

    test('显式索引 0（白色）在深色主题下 → 保留 white（显式 0 ≠ 未设置）', () {
      final resolved = resolveReaderBackground(
        themeBrightness: Brightness.dark,
        themeAmoled: true,
        storedBgIndex: 0,
        customBgColor: null,
      );
      expect(resolved, equals(ReaderBackground.white));
    });

    test('深色主题 + 自定义背景色 → custom 优先', () {
      final resolved = resolveReaderBackground(
        themeBrightness: Brightness.dark,
        themeAmoled: true,
        storedBgIndex: null,
        customBgColor: custom,
      );
      expect(resolved, equals(custom));
    });

    test('自定义色与显式索引并存 → 自定义优先', () {
      final resolved = resolveReaderBackground(
        themeBrightness: Brightness.dark,
        themeAmoled: true,
        storedBgIndex: 1,
        customBgColor: custom,
      );
      expect(resolved, equals(custom));
    });

    test('深色主题 + 越界索引 99 → 视为未设置，回落普通深色默认', () {
      final resolved = resolveReaderBackground(
        themeBrightness: Brightness.dark,
        storedBgIndex: 99,
        customBgColor: null,
      );
      expect(resolved, equals(ReaderBackground.dark));
    });

    test('亮色主题 + 负数索引 → 视为未设置，回落白色', () {
      final resolved = resolveReaderBackground(
        themeBrightness: Brightness.light,
        storedBgIndex: -1,
        customBgColor: null,
      );
      expect(resolved, equals(ReaderBackground.white));
    });
  });

  group('themeBrightnessFor 主题模式 → 有效亮度', () {
    test('ThemeMode.light → light（无视平台亮度）', () {
      expect(
        themeBrightnessFor(ThemeMode.light, Brightness.dark),
        equals(Brightness.light),
      );
    });

    test('ThemeMode.dark → dark（无视平台亮度）', () {
      expect(
        themeBrightnessFor(ThemeMode.dark, Brightness.light),
        equals(Brightness.dark),
      );
    });

    test('ThemeMode.system → 透传平台亮度（dark）', () {
      expect(
        themeBrightnessFor(ThemeMode.system, Brightness.dark),
        equals(Brightness.dark),
      );
    });

    test('ThemeMode.system → 透传平台亮度（light）', () {
      expect(
        themeBrightnessFor(ThemeMode.system, Brightness.light),
        equals(Brightness.light),
      );
    });
  });
}
