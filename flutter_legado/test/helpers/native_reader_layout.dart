import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';
import 'package:flutter_legado/src/services/reader_layout_service.dart';

/// 每个测试进程加载一次正式绑定；排版不需要数据库或应用启动。— Codex + Bridge
void setUpNativeReaderLayout() {
  setUpAll(() async {
    final configured = Platform.environment['LEGADO_TEST_FFI_LIBRARY'];
    final name = Platform.isWindows
        ? 'legado_ffi.dll'
        : Platform.isMacOS
        ? 'liblegado_ffi.dylib'
        : 'liblegado_ffi.so';
    final library = File(configured ?? '../rust/target/debug/$name');
    if (!library.existsSync()) {
      throw StateError(
        '缺少当前平台的正式 FFI 库：${library.absolute.path}；请先构建 legado-ffi，'
        '复用其他 Cargo 目录时设置 LEGADO_TEST_FFI_LIBRARY。',
      );
    }
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(library.absolute.path),
    );
  });
  tearDown(() => nativeReaderLayout.closeRemaining());
  tearDownAll(RustLib.dispose);
}

final nativeReaderLayout = _TrackedNativeLayout();

/// 只追踪正式异步调用以驱动测试时钟，不重写算法、返回协议或句柄生命周期。
class _TrackedNativeLayout implements ReaderLayoutTransport {
  final _delegate = const NativeReaderLayoutTransport();
  final _pending = <Future<void>>{};
  final _handles = <Object>{};

  Future<T> _track<T>(Future<T> Function() call) {
    final caller = Zone.current;
    final result = Completer<T>();
    Zone.root.run(() {
      final settled = Completer<void>();
      _pending.add(settled.future);
      // I/O使用真实调度；值与错误送回原测试Zone，不能丢到根Zone。
      unawaited(
        Future<T>.sync(call)
            .then<void>(
              (value) => caller.run(() => result.complete(value)),
              onError: (Object error, StackTrace stack) {
                if (error is AppException) {
                  debugPrint('原生排版错误：${error.message}');
                }
                caller.run(() => result.completeError(error, stack));
              },
            )
            .whenComplete(() {
              _pending.remove(settled.future);
              settled.complete();
            }),
      );
    });
    return result.future;
  }

  Future<void> drain() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  @override
  Future<ReaderLayoutReply> begin(Map<String, Object?> config) =>
      _track(() async {
        final reply = await _delegate.begin(config);
        _handles.add(reply.sessionId);
        return reply;
      });

  @override
  Future<ReaderLayoutReply> push(
    Object id,
    List<Map<String, Object?>> blocks,
  ) => _track(() => _delegate.push(id, blocks));

  @override
  Future<ReaderLayoutReply> finish(Object id) => _track(() async {
    try {
      return await _delegate.finish(id);
    } finally {
      _handles.remove(id);
    }
  });

  @override
  Future<void> cancel(Object id) => _track(() async {
    try {
      await _delegate.cancel(id);
    } finally {
      _handles.remove(id);
    }
  });

  Future<void> closeRemaining() async {
    await drain();
    for (final id in _handles.toList()) {
      await cancel(id);
    }
    await drain();
  }
}

Widget nativeReaderLayoutBuilder(BuildContext context, Widget? child) =>
    ReaderLayoutTransportScope(
      transport: nativeReaderLayout,
      child: child ?? const SizedBox.shrink(),
    );

/// 真正等待原生回调并推进 Widget；不靠固定延时假定布局已结束。
Future<void> settleNativeReaderLayout(WidgetTester tester) async {
  for (var round = 0; round < 1000; round++) {
    await tester.runAsync(nativeReaderLayout.drain);
    // 分批分页在帧尾继续；逐帧等待I/O，避免加载动画独占fake时钟直到超时。
    await tester.pump(const Duration(milliseconds: 100));
    if (nativeReaderLayout._pending.isEmpty &&
        !tester.binding.hasScheduledFrame) {
      return;
    }
  }
  throw StateError('原生排版测试未收敛，请检查持续重排或未关闭的会话。');
}

Future<void> pumpNativeReaderLayout(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await settleNativeReaderLayout(tester);
}

/// 异步排版之后再挂载原测试界面，不把 Future 当成同步页面列表。
class LayoutTestBuilder extends StatefulWidget {
  final Future<Widget> Function(BuildContext) builder;
  const LayoutTestBuilder({super.key, required this.builder});
  @override
  State<LayoutTestBuilder> createState() => _LayoutTestBuilderState();
}

class _LayoutTestBuilderState extends State<LayoutTestBuilder> {
  Future<Widget>? _result;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _result ??= widget.builder(context);
  }

  @override
  void didUpdateWidget(LayoutTestBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.builder != oldWidget.builder) _result = widget.builder(context);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _result,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        Error.throwWithStackTrace(snapshot.error!, snapshot.stackTrace!);
      }
      return snapshot.data ?? const SizedBox.shrink();
    },
  );
}
