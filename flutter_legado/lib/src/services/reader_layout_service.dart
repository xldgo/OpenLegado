import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../bridge/ffi.dart' as bridge;
import 'reader_layout_data.dart';
import '../widgets/reader/layout_diagnostics.dart';

/// 传输适配器只处理批量协议；断行和分页只有 Rust 一个实现。
abstract interface class ReaderLayoutTransport {
  Future<String> begin(String configJson);
  Future<String> push(String sessionId, String blocksJson);
  Future<String> finish(String sessionId);
  Future<void> cancel(String sessionId);
}

/// 测试与宿主可注入传输层，生产缺省仍只调用 Rust；不提供 Dart 算法回退。
class ReaderLayoutTransportScope extends InheritedWidget {
  final ReaderLayoutTransport transport;
  const ReaderLayoutTransportScope({
    super.key,
    required this.transport,
    required super.child,
  });
  static ReaderLayoutTransport? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReaderLayoutTransportScope>()
      ?.transport;
  @override
  bool updateShouldNotify(ReaderLayoutTransportScope oldWidget) =>
      transport != oldWidget.transport;
}

class NativeReaderLayoutTransport implements ReaderLayoutTransport {
  const NativeReaderLayoutTransport();
  @override
  Future<String> begin(String configJson) =>
      bridge.readerLayoutBegin(configJson: configJson);
  @override
  Future<String> push(String sessionId, String blocksJson) =>
      bridge.readerLayoutPush(sessionId: sessionId, blocksJson: blocksJson);
  @override
  Future<String> finish(String sessionId) =>
      bridge.readerLayoutFinish(sessionId: sessionId);
  @override
  Future<void> cancel(String sessionId) =>
      bridge.readerLayoutCancel(sessionId: sessionId);
}

class ReaderLayoutCancelled implements Exception {
  const ReaderLayoutCancelled();
  @override
  String toString() => '阅读布局会话已取消';
}

class ReaderLayoutReply {
  final String sessionId;
  final List<Map<String, dynamic>> pages;
  final int rustMicroseconds;
  ReaderLayoutReply._(this.sessionId, this.pages, this.rustMicroseconds);

  factory ReaderLayoutReply.decode(String encoded) {
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic> ||
        value['schemaVersion'] != 1 ||
        value['sessionId'] is! String ||
        (value['sessionId'] as String).isEmpty ||
        value['pages'] is! List ||
        value['rustMicros'] is! int ||
        (value['rustMicros'] as int) < 0) {
      throw const FormatException('阅读布局返回协议无效');
    }
    final columns = ReaderGlyphColumns.decode(
      value['glyphs'],
      value['textStyles'],
    );
    final pages = <Map<String, dynamic>>[];
    for (final page in value['pages'] as List) {
      if (page is! Map<String, dynamic>) {
        throw const FormatException('阅读布局页面不是对象');
      }
      page['elements'] = ReaderElementDataList.decode(
        page['elements'],
        columns,
      );
      pages.add(Map.unmodifiable(page));
    }
    return ReaderLayoutReply._(
      value['sessionId'] as String,
      List.unmodifiable(pages),
      value['rustMicros'] as int,
    );
  }
}

/// 会话可在 begin 尚未返回时取消；串行推送并拒绝迟到的页面。
class ReaderLayoutSession {
  final ReaderLayoutTransport transport;
  final ReaderLayoutDiagnostics? diagnostics;
  late final Future<String> _identifier;
  Future<void> _tail = Future.value();
  Future<void>? _cancellation;
  bool _cancelled = false;
  bool _closing = false;
  bool _closed = false;

  ReaderLayoutSession({
    required Map<String, Object?> config,
    this.transport = const NativeReaderLayoutTransport(),
    this.diagnostics,
  }) {
    _identifier = _begin(config);
    // begin 错误仍由 push/finish 报告，避免调用者尚未推进时出现未处理异步异常。
    _identifier.ignore();
  }

  bool get cancelled => _cancelled;
  bool get closed => _closed;

  Future<String> _begin(Map<String, Object?> config) async {
    final payload = _encode({'schemaVersion': 1, 'config': config});
    final reply = await _request(() => transport.begin(payload));
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
      final payload = _encode({'schemaVersion': 1, 'blocks': blocks});
      final reply = await _request(() => transport.push(id, payload));
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

  void _checkReply(ReaderLayoutReply reply, String id) {
    _checkActive();
    if (reply.sessionId != id) {
      throw const FormatException('阅读布局返回了其他会话的页面');
    }
  }

  Future<void> cancel() {
    _cancelled = true;
    return _cancellation ??= () async {
      String id;
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

  String _encode(Map<String, Object?> value) {
    final timer = diagnostics == null ? null : (Stopwatch()..start());
    final encoded = jsonEncode(value);
    if (timer != null) {
      diagnostics!.encodingMicroseconds += timer.elapsedMicroseconds;
    }
    return encoded;
  }

  Future<ReaderLayoutReply> _request(Future<String> Function() call) async {
    final timer = diagnostics == null ? null : (Stopwatch()..start());
    final encoded = await call();
    if (timer != null) {
      diagnostics!.ffiCalls++;
      diagnostics!.callMicroseconds += timer.elapsedMicroseconds;
      timer.reset();
    }
    final reply = ReaderLayoutReply.decode(encoded);
    if (timer != null) {
      diagnostics!.decodingMicroseconds += timer.elapsedMicroseconds;
      diagnostics!.rustMicroseconds += reply.rustMicroseconds;
    }
    return reply;
  }
}
