import 'dart:async';

import 'package:flutter_legado/src/app/bootstrap/restored_settings_refresher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('按顺序刷新，单项失败继续其他设置及书架并返回失败项', () async {
    final calls = <String>[];
    final refresher = RestoredSettingsRefresher([
      (
        '主题',
        () async {
          calls.add('主题');
          throw StateError('同步失败');
        },
      ),
      (
        '颜色',
        () async {
          calls.add('颜色');
        },
      ),
      (
        '书架',
        () async {
          calls.add('书架');
        },
      ),
    ]);
    expect(await refresher.refresh(), ['主题']);
    expect(calls, ['主题', '颜色', '书架']);
  });
  test('已启动刷新不依赖页面状态，中途等待后仍完成剩余步骤', () async {
    final gate = Completer<void>();
    final calls = <String>[];
    final refresher = RestoredSettingsRefresher([
      (
        '主题',
        () async {
          calls.add('主题');
          await gate.future;
        },
      ),
      (
        '书架',
        () async {
          calls.add('书架');
        },
      ),
    ]);
    final running = refresher.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['主题']);
    gate.complete();
    expect(await running, isEmpty);
    expect(calls, ['主题', '书架']);
  });
}
