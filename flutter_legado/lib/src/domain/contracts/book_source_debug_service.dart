import '../models/book_source_debug_event.dart';

/// 复用现有全局调试流；调用者管理订阅生命周期。— Codex + Bridge
abstract interface class BookSourceDebugService {
  Stream<BookSourceDebugEvent> debug(String sourceUrl, String key);
  Future<void> cancel();
}
