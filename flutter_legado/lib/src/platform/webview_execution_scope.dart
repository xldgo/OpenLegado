import 'dart:async';

/// 单次平台执行的取消与清理边界，不持有页面或跨请求状态。— Codex + Bridge
class WebViewExecutionScope {
  final _cancelled = Completer<void>();
  final _cleanups = <Future<void> Function()>[];
  Future<void>? _closing;
  bool get isCancelled => _cancelled.isCompleted;

  void check() {
    if (isCancelled) throw const WebViewExecutionCancelled();
  }

  void onClose(Future<void> Function() cleanup) {
    check();
    _cleanups.add(cleanup);
  }

  Future<T> wait<T>(Future<T> work) {
    // work在调用前已创建，取消后也须订阅它，消费平台迟到的失败。
    return Future.any([
      work,
      _cancelled.future.then<T>((_) => throw const WebViewExecutionCancelled()),
    ]).then((value) {
      check();
      return value;
    });
  }

  Future<void> close() {
    if (!_cancelled.isCompleted) _cancelled.complete();
    return _closing ??= _close();
  }

  Future<void> _close() async {
    final callbacks = _cleanups.reversed.toList();
    _cleanups.clear();
    for (final callback in callbacks) {
      try {
        await callback();
      } catch (_) {
        // 一项平台清理失败不得阻止其余资源释放。
      }
    }
  }
}

class WebViewExecutionCancelled implements Exception {
  const WebViewExecutionCancelled();
  @override
  String toString() => 'WebView请求已取消';
}
