import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_legado/src/domain/models/appearance_settings.dart';
import 'package:flutter_legado/src/features/appearance/widgets/builtin_palette_selector.dart';
import 'package:flutter_legado/src/l10n/app_localization.dart';
import 'package:flutter_legado/src/theme/platform_dynamic_colors.dart';
import 'package:flutter_legado/src/widgets/settings_widgets.dart';

void main() {
  final light = ColorScheme.fromSeed(seedColor: Colors.green);
  final dark = ColorScheme.fromSeed(
    seedColor: Colors.orange,
    brightness: Brightness.dark,
  );
  final outline = ColorScheme.fromSeed(seedColor: Colors.purple);

  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: brightness == Brightness.light ? outline : dark,
        ),
        home: PlatformDynamicColors(
          light: light,
          dark: dark,
          child: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );

  testWidgets('系统预览共享对应亮度的完整色板，点击切换互斥选择', (tester) async {
    var selected = AppearanceSettings.dynamicPaletteId;
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 360,
              child: BuiltinPaletteSelector(
                selectedId: selected,
                onSelected: (id) => setState(() => selected = id),
              ),
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      final preview = tester.widget<Card>(find.byType(Card).first);
      expect(
        preview.color,
        (brightness == Brightness.light ? light : dark).surfaceContainer,
      );
      await tester.tap(find.text('草野'));
      await tester.pumpAndSettle();
      expect(selected, 'gr');
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('动态取色'));
      await tester.pumpAndSettle();
      expect(selected, AppearanceSettings.dynamicPaletteId);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('窄容器首尾选中卡片的边框真实绘制完整，大字不溢出', (tester) async {
    final boundaryKey = GlobalKey();
    final selectorKey = GlobalKey();
    var selected = AppearanceSettings.dynamicPaletteId;
    await tester.pumpWidget(
      host(
        RepaintBoundary(
          key: boundaryKey,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(
              width: 240,
              child: SettingsGroup(
                children: [
                  StatefulBuilder(
                    builder: (context, setState) => BuiltinPaletteSelector(
                      key: selectorKey,
                      selectedId: selected,
                      onSelected: (id) => setState(() => selected = id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> checkBorder(Finder card) async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final rect = tester
          .getRect(card)
          .shift(-tester.getTopLeft(find.byKey(boundaryKey)));
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(rect.right, lessThanOrEqualTo(224));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          for (final point in [
            Offset(rect.left + 1, rect.center.dy),
            Offset(rect.right - 1, rect.center.dy),
            Offset(rect.center.dx, rect.top + 1),
            Offset(rect.center.dx, rect.bottom - 1),
          ]) {
            final offset =
                (point.dy.floor() * image.width + point.dx.floor()) * 4;
            final color = Color.fromARGB(
              bytes.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
            expect(color, outline.primary, reason: '边框像素 $point');
          }
        } finally {
          image.dispose();
        }
      });
    }

    await checkBorder(find.byType(Card).first);
    final scrollable = find.descendant(
      of: find.byKey(selectorKey),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('默认'),
      160,
      scrollable: scrollable,
    );
    await tester.tap(find.text('默认'));
    await tester.pumpAndSettle();
    expect(selected, 'def');
    await checkBorder(find.byType(Card).last);
    expect(tester.takeException(), isNull);
  });
}
