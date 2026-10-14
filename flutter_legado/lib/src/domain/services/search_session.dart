import 'dart:async';

import '../contracts/search_service.dart';
import '../models/search_batch.dart';

/// 一次查询的执行对象与订阅；不持有 Flutter 或展示结果。— Codex + Bridge
final class SearchSession {
  SearchSession(this.service);

  final SearchService service;
  StreamSubscription<SearchBatch>? _subscription;
  int _pageGeneration = 0;
  int _controlGeneration = 0;
  bool _closed = false;
  bool _running = false;
  bool _paused = false;
  bool _requestedPaused = false;
  Future<void> _controls = Future<void>.value();
  Future<bool>? _control;
  Future<void>? _closing;

  bool get requestedPaused => _requestedPaused;

  /// 上一页的迟到控制也必须在下一页启动前结束。
  Future<void> get controlsSettled => _controls;

  /// 自然完成后可继续下一页，查询期间始终绑定同一执行实例。
  void start({
    required String keyword,
    required int page,
    required List<String>? sourceUrls,
    required void Function(SearchBatch batch) onBatch,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) {
    if (_closed || _running) throw StateError('搜索会话已关闭或仍有活动页面');
    final generation = ++_pageGeneration;
    _running = true;
    _paused = false;
    try {
      final subscription = service
          .searchMultiStream(keyword, sourceUrls: sourceUrls, page: page)
          .listen(
            (batch) {
              if (_ownsPage(generation)) onBatch(batch);
            },
            onError: (Object error) {
              if (_ownsPage(generation)) onError(error);
            },
            onDone: () {
              if (!_ownsPage(generation)) return;
              _running = false;
              _requestedPaused = false;
              _subscription = null;
              onDone();
            },
          );
      // 同步流也可能在 listen 返回前完成或触发关闭。
      if (_ownsPage(generation)) {
        _subscription = subscription;
      } else {
        unawaited(subscription.cancel());
      }
    } catch (_) {
      _running = false;
      rethrow;
    }
  }

  bool _ownsPage(int generation) =>
      !_closed && _running && generation == _pageGeneration;

  /// 合并重复控制并串行执行；过期结果不得改变当前展示状态。
  Future<bool> setPaused(bool paused) {
    if (_closed) return Future<bool>.value(false);
    if (!_running) {
      // 准备期只记录前后台意图，启动后由协调层应用。
      _requestedPaused = paused;
      return Future<bool>.value(false);
    }
    if (_requestedPaused == paused && _control != null) return _control!;
    _requestedPaused = paused;
    final generation = ++_controlGeneration;
    final pageGeneration = _pageGeneration;
    final previous = _controls;
    final operation = () async {
      await previous;
      if (!_ownsPage(pageGeneration) || generation != _controlGeneration) {
        return false;
      }
      if (_paused != paused) {
        if (paused) {
          await service.pauseSearch();
        } else {
          await service.resumeSearch();
        }
      }
      if (!_ownsPage(pageGeneration)) return false;
      _paused = paused;
      return generation == _controlGeneration;
    }();
    _control = operation;
    // 队列继续可用；调用者仍收到本次原始错误。
    _controls = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    unawaited(
      _controls.then((_) {
        if (identical(_control, operation)) _control = null;
      }),
    );
    return operation;
  }

  /// 先让回调失效，再原生取消、解绑，等待在途控制后允许下一查询。
  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    final wasRunning = _running;
    _running = false;
    _pageGeneration++;
    _controlGeneration++;
    final subscription = _subscription;
    _subscription = null;
    final controls = _controls;
    return _closing = () async {
      try {
        if (wasRunning) await service.cancelSearch();
      } finally {
        try {
          await subscription?.cancel();
        } finally {
          await controls;
        }
      }
    }();
  }
}
