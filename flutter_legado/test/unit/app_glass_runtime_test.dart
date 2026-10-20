import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/theme/app_glass_runtime.dart';

void main() {
  test('并发与重复初始化只预热一次，就绪后才能使用玻璃', () async {
    final completed = Completer<void>();
    var calls = 0;
    final runtime = AppGlassRuntime(
      initialize: () {
        calls++;
        return completed.future;
      },
    );
    expect(runtime.available, isFalse);
    final first = runtime.initialize();
    final second = runtime.initialize();
    expect(first, same(second));
    expect(runtime.available, isFalse);
    completed.complete();
    await Future.wait([first, second]);
    await runtime.initialize();
    expect(calls, 1);
    expect(runtime.available, isTrue);
    expect(runtime.error, isNull);
  });

  test('异步预热失败不向启动流程抛错，也不在重建时重试', () async {
    final failure = StateError('资源不可用');
    var calls = 0;
    final runtime = AppGlassRuntime(
      initialize: () async {
        calls++;
        throw failure;
      },
    );
    await runtime.initialize();
    await runtime.initialize();
    expect(runtime.available, isFalse);
    expect(runtime.error, same(failure));
    expect(calls, 1);
  });

  test('同步预热异常同样保留普通材质', () async {
    final failure = StateError('初始化异常');
    final runtime = AppGlassRuntime(initialize: () => throw failure);
    await runtime.initialize();
    expect(runtime.available, isFalse);
    expect(runtime.error, same(failure));
  });
}
