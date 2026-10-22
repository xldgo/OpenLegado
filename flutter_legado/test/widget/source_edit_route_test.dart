import '../fixtures/app_test_api.dart';

// 书源编辑页转场回归测试
//
// 根因（2026-10-22）：编辑页在转场首帧回填全部字段，浮动标签动画 167ms 短于
// 平台默认转场（Android FadeForwards 450ms / 桌面 Zoom 300ms）；转场快照
// （SnapshotWidget）把进入页栅格化，标签动画整段被冻结，转场结束瞬间跳到
// 终态，表现为「无动画地从无输入变为有输入」。
//
// 本用例验证统一入口 [sourceEditRoute] 关闭了转场快照，且转场过程中标签
// 确实存在中间帧（动画可见），避免回归为瞬时跳变。
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/features/book_sources/book_sources.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/theme/app_theme_resolver.dart';

import '../mocks/mocks.dart';

const _source = BookSource(
  bookSourceUrl: 'https://route.test',
  bookSourceName: '路由源',
  bookSourceGroup: '分组A',
);

/// 走统一入口打开编辑页，逐帧采样标签位置，断言转场期间动画可见。
Future<void> _expectLabelAnimatesDuringTransition(
  WidgetTester tester,
) async {
  final mockApi = MockRustApi();
  when(
    () => mockApi.bookSourceRepository.getBookSources(),
  ).thenAnswer((_) async => [_source]);
  final container = ProviderContainer(
    overrides: mergeTestOverrides([...mockApi.overrides]),
  );
  addTearDown(container.dispose);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  // 预加载书源，使 _loadSource 在首帧 post-frame 同步回填（最坏情形）
  await container.read(sourceNotifierProvider.notifier).loadSources();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: resolveAppThemes(
          preferences: const AppThemePreferences(),
        ).light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  sourceEditRoute(sourceUrl: _source.bookSourceUrl),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));

  /// 标签相对第一个输入框的垂直偏移；越小越靠上（更接近上浮终态）。
  /// 页面/标签尚未构建时返回 null，避免把首帧空树当作采样值。
  double? labelOffset() {
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((d) => d.contains('sourceName'))
        .toList();
    if (labels.isEmpty) return null;
    final field = find.byType(TextField);
    if (field.evaluate().isEmpty) return null;
    return tester.getTopLeft(find.text(labels.first)).dy -
        tester.getTopLeft(field.first).dy;
  }

  // 逐帧采样覆盖整个转场窗口（桌面 300ms / Android 450ms）。
  final samples = <double>[];
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final value = labelOffset();
    if (value != null) samples.add(value);
  }
  await tester.pumpAndSettle();
  final settled = labelOffset();
  expect(settled, isNotNull, reason: '转场结束后应渲染书源名称标签');

  expect(samples, isNotEmpty, reason: '应采集到转场期间的标签位置');
  final start = samples.first;
  expect(
    settled!,
    lessThan(start),
    reason: '回填后标签应上浮到终态（$settled < $start）',
  );
  // 关键断言：转场窗口内出现过严格位于起止之间的中间态。
  // 若转场被快照冻结，采样只会出现 start（冻结）与 settled（跳变后）。
  final settledValue = settled;
  final hasIntermediate = samples.any(
    (v) => v < start - 0.5 && v > settledValue + 0.5,
  );
  expect(
    hasIntermediate,
    isTrue,
    reason:
        '转场期间应出现标签上浮的中间帧（动画可见）；'
        '实际采样=${samples.map((v) => v.toStringAsFixed(1)).toList()} '
        'settled=${settledValue.toStringAsFixed(1)}',
  );
}

void main() {
  setUpAll(registerFallbacks);

  testWidgets('统一入口关闭转场快照', (tester) async {
    final route = sourceEditRoute(sourceUrl: _source.bookSourceUrl);
    expect(route.allowSnapshotting, isFalse);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('${platform.name} 转场期间浮动标签存在中间帧', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await _expectLabelAnimatesDuringTransition(tester);
      } finally {
        // 必须在用例体内复位：测试框架在 tearDown 之前校验 foundation 调试变量。
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
