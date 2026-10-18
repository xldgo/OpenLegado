import 'rust_errors.dart';

import 'dart:async';

import '../../bridge/ffi.dart' as bridge;

/// 每个订阅只取消自己持有的 Rust 凭据，不调用当前任务的全局取消入口。— Codex + Bridge
Stream<T> managedRustStream<T>(Stream<T> Function(bridge.StreamRequest) start) {
  late StreamController<T> controller;
  StreamSubscription<T>? upstream;
  bridge.StreamRequest? request;
  var stopped = false;
  void release() {
    request?.dispose();
    request = null;
  }

  controller = StreamController<T>(
    onListen: () {
      try {
        request = rustCall(
          () => bridge.streamRequestNew(),
          operation: 'streamRequestNew',
        );
        upstream = start(request!).listen(
          (value) {
            if (!stopped) controller.add(value);
          },
          onError: (Object error, StackTrace stack) {
            if (!stopped) controller.addError(error, stack);
          },
          onDone: () {
            release();
            if (!stopped) unawaited(controller.close());
          },
        );
      } catch (error, stack) {
        release();
        controller.addError(error, stack);
        unawaited(controller.close());
      }
    },
    onCancel: () async {
      stopped = true;
      request?.cancel();
      try {
        await upstream?.cancel();
      } finally {
        release();
      }
    },
  );
  return controller.stream;
}
