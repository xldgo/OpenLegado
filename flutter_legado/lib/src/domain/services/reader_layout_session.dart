import 'dart:async';

import '../contracts/reader_layout_transport.dart';
import '../errors/reader_layout_cancelled.dart';
import '../models/reader_layout_reply.dart';
import '../models/reader_layout_diagnostics.dart';

/// 会话可在 begin 尚未返回时取消；串行推送并拒绝迟到的页面。
class ReaderLayoutSession {
  final ReaderLayoutTransport transport;
  final ReaderLayoutDiagnostics? diagnostics;
  late final Future<Object> _identifier;
  Future<void> _tail = Future.value();
  Future<void>? _cancellation;
  bool _cancelled = false;
  bool _closing = false;
  bool _closed = false;

  ReaderLayoutSession({
    required Map<String, Object?> config,
    required this.transport,
    this.diagnostics,
  }) {
    _identifier = _begin(config);
    // begin 错误仍由 push/finish 报告，避免调用者尚未推进时出现未处理异步异常。
    _identifier.ignore();
  }

  bool get cancelled => _cancelled;
  bool get closed => _closed;

  Future<Object> _begin(Map<String, Object?> config) async {
    final reply = await _request(() => transport.begin(config));
    if (reply.pages.isNotEmpty) {
      await transport.cancel(reply.sessionId);
      throw const FormatException('阅读布局 begin 不应返回页面');
    }
    return reply.sessionId;
  }

  Future<ReaderLayoutReply> push(List<Map<String, Object?>> blocks) {
    if (_closing || _closed || _cancelled) {
      return Future.error(const ReaderLayoutCancelled());
    }
    return _enqueue(() async {
      final id = await _identifier;
      _checkActive();
      final reply = await _request(() => transport.push(id, blocks));
      _checkReply(reply, id);
      return reply;
    });
  }

  Future<ReaderLayoutReply> finish() {
    if (_closing || _closed || _cancelled) {
      return Future.error(const ReaderLayoutCancelled());
    }
    _closing = true;
    return _enqueue(() async {
      final id = await _identifier;
      _checkActive();
      final reply = await _request(() => transport.finish(id));
      _checkReply(reply, id);
      _closed = true;
      return reply;
    });
  }

  Future<ReaderLayoutReply> _enqueue(
    Future<ReaderLayoutReply> Function() operation,
  ) {
    final result = _tail.then((_) async {
      try {
        _checkActive();
        return await operation();
      } catch (_) {
        // 服务端失败会释放会话；解码失败同样清理，保留原始异常。
        try {
          await cancel();
        } catch (_) {}
        rethrow;
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _checkActive() {
    if (_cancelled || _closed) throw const ReaderLayoutCancelled();
  }

  void _checkReply(ReaderLayoutReply reply, Object id) {
    _checkActive();
    if (reply.sessionId != id) {
      throw const FormatException('阅读布局返回了其他会话的页面');
    }
  }

  Future<void> cancel() {
    _cancelled = true;
    return _cancellation ??= () async {
      Object id;
      try {
        id = await _identifier;
      } catch (_) {
        _closed = true;
        return;
      }
      await transport.cancel(id);
      _closed = true;
    }();
  }

  Future<ReaderLayoutReply> _request(
    Future<ReaderLayoutReply> Function() call,
  ) async {
    final timer = diagnostics == null ? null : (Stopwatch()..start());
    final reply = await call();
    if (timer != null) {
      diagnostics!.ffiCalls++;
      diagnostics!.callMicroseconds += timer.elapsedMicroseconds;
      // 类型化传输的字段映射计入调用总耗时；不再伪造 JSON 编解码阶段。
      diagnostics!.rustMicroseconds += reply.rustMicroseconds;
    }
    return reply;
  }
}
