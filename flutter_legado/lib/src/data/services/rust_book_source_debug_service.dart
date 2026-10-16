import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/book_source_debug_service.dart';
import '../../domain/models/book_source_debug_event.dart';
import '../bridge/rust_json_decode.dart';

/// 直接消费既有Rust调试流与取消信号。— Codex + Bridge
final class RustBookSourceDebugService implements BookSourceDebugService {
  const RustBookSourceDebugService();
  @override
  Stream<BookSourceDebugEvent> debug(String sourceUrl, String key) =>
      bridge.debugBookSourceStream(sourceUrl: sourceUrl, key: key).map((raw) {
        final value = decodeRustJsonMap(raw, 'debugBookSourceStream');
        final state = value['state'];
        return BookSourceDebugEvent(
          state: state is int ? state : int.tryParse('$state') ?? 1,
          message: (value['msg'] ?? '').toString(),
        );
      });
  @override
  Future<void> cancel() async {
    await bridge.debugBookSourceCancel();
  }
}
