import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_source_debug_service.dart';
import '../../domain/models/book_source_debug_event.dart';
import '../bridge/managed_rust_stream.dart';

/// 直接消费既有Rust调试流与取消信号。— Codex + Bridge
final class RustBookSourceDebugService implements BookSourceDebugService {
  const RustBookSourceDebugService();
  @override
  Stream<BookSourceDebugEvent> debug(String sourceUrl, String key) =>
      managedRustStream(
        (request) => rustStream(
          () => bridge.debugBookSourceStream(
            sourceUrl: sourceUrl,
            key: key,
            request: request,
          ),
          operation: 'debugBookSourceStream',
        ),
      ).map(
        (value) => BookSourceDebugEvent(state: value.state, message: value.msg),
      );
  @override
  Future<void> cancel() async {
    await rustFuture(
      () => bridge.debugBookSourceCancel(),
      operation: 'debugBookSourceCancel',
    );
  }
}
