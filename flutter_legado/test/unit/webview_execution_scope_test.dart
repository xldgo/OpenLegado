import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/platform/webview_execution_scope.dart';

void main() {
  test('取消立即结束等待，迟到失败被消费，清理只执行一次', () async {
    final scope = WebViewExecutionScope();
    final work = Completer<String>();
    var closed = 0;
    scope.onClose(() async {
      closed++;
    });
    final assertion = expectLater(
      scope.wait(work.future),
      throwsA(isA<WebViewExecutionCancelled>()),
    );
    await scope.close();
    await assertion;
    work.completeError(StateError('迟到错误'));
    await Future<void>.delayed(Duration.zero);
    await scope.close();
    expect(closed, 1);
    final late = Completer<String>();
    final cancelled = expectLater(
      scope.wait(late.future),
      throwsA(isA<WebViewExecutionCancelled>()),
    );
    late.completeError(StateError('已取消后创建的异步操作'));
    await cancelled;
  });

  test('成功空结果有效，清理按反序执行且一项失败不阻断', () async {
    final scope = WebViewExecutionScope();
    final order = <int>[];
    scope.onClose(() async {
      order.add(1);
    });
    scope.onClose(() async {
      order.add(2);
      throw StateError('清理失败');
    });
    expect(await scope.wait(Future.value('')), '');
    await scope.close();
    expect(order, [2, 1]);
    expect(scope.check, throwsA(isA<WebViewExecutionCancelled>()));
  });
}
