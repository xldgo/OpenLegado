import 'dart:async';
import 'dart:collection';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../providers/source_interaction_provider.dart';
import '../domain/contracts/webview_bridge_service.dart';
import '../domain/models/webview_request.dart';

/// 全局 BackstageWebView DOM 执行监听器（SOURCE_DIFF P1）
///
/// 挂载于 MaterialApp.builder：订阅 WebViewBridgeService.webviewRequestStream，
/// Rust 侧 `@webjs` / 正文 webJs / `java.webView*` 挂起时用真实 WebView
/// 执行并经 `submitWebviewResultWithCookies` 回传（B1：结果 + 域 cookie
/// 回流，cookie 为空时语义同 [WebViewBridgeService.submitWebviewResult]）。
///
/// 无可见 UI（后台 WebView）；桌面无 WebView 能力时回传错误串唤醒等待方。
///
/// B3：执行并发池（对齐上游 WebViewPool 容量 5）——至多 5 个 WebView
/// 并行执行，超出并行度的请求按 FIFO 排队，任务结束后补位队头。
/// 各请求 key 唯一（Rust 侧按 key 唤醒等待方），并行不互相覆盖。
///
/// — WebViewBridge + Bridge｜2026-08-13｜项 B/B1 cookie 回流
/// ｜2026-09-26 项 B/B3 并发池（并行度 5 + FIFO）
class WebViewBridgeListener extends ConsumerStatefulWidget {
  final Widget child;

  const WebViewBridgeListener({super.key, required this.child});

  @override
  ConsumerState<WebViewBridgeListener> createState() =>
      _WebViewBridgeListenerState();
}

class _WebViewBridgeListenerState extends ConsumerState<WebViewBridgeListener> {
  StreamSubscription<WebViewRequest>? _subscription;
  late final WebViewBridgeService _service;
  late final WebViewRequestExecutor _executor;
  final Set<String> _active = {};
  bool _closed = false;

  // ========== B3 并发池（对齐上游 WebViewPool 容量 5） ==========

  /// 并行度上限：至多 5 个 WebView 同时执行（对齐上游 WebViewPool 容量 5；
  /// 原单 `_chain` 全串行，多书源并发抓取时互相排队放大延迟）
  static const int _maxConcurrency = 5;

  /// 当前在途任务数（信号量计数）
  int _inFlight = 0;

  /// FIFO 排队：超出并行度的事件按到达顺序排队，槽位释放后补位队头
  final Queue<WebViewRequest> _pending = Queue();

  @override
  void initState() {
    super.initState();
    _service = ref.read(webViewBridgeServiceProvider);
    _executor = ref.read(webViewRequestExecutorProvider);
    _subscription = _service.webviewRequestStream().listen(
      _onRequest,
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_subscription?.cancel());
    final keys = {..._active, ..._pending.map((e) => e.key)};
    _pending.clear();
    for (final key in keys) {
      unawaited(_cancel(key));
    }
    super.dispose();
  }

  void _onRequest(WebViewRequest event) {
    if (!mounted) return;
    final key = event.key;
    if (key.isEmpty) return;
    if (_inFlight < _maxConcurrency) {
      _start(event);
    } else {
      _pending.add(event);
    }
  }

  /// 占用一个槽位执行任务；结束时释放槽位并补位队头（FIFO）
  void _start(WebViewRequest event) {
    _inFlight++;
    _active.add(event.key);
    _handle(event)
        .whenComplete(() {
          _inFlight--;
          _active.remove(event.key);
          if (!_closed && _pending.isNotEmpty) {
            _start(_pending.removeFirst());
          }
        })
        .catchError((Object e) {
          debugPrint('[WebViewBridge] 处理失败：$e');
        });
  }

  Future<void> _handle(WebViewRequest event) async {
    final key = event.key;
    try {
      final outcome = await _executor.execute(event);
      if (_closed) return;
      await _service.submitWebviewResultWithCookies(
        key,
        outcome.result,
        outcome.cookies,
      );
    } catch (e, st) {
      debugPrint('[WebViewBridge] 执行/回传失败：$e\n$st');
      if (!_closed) await _service.submitWebviewResult(key, '[ERROR] $e');
    }
  }

  Future<void> _cancel(String key) async {
    try {
      await _service.cancelWebviewRequest(key);
    } catch (error) {
      debugPrint('WebView请求取消失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
