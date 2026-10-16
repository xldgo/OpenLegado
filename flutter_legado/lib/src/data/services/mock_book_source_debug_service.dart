import '../../domain/contracts/book_source_debug_service.dart';
import '../../domain/models/book_source_debug_event.dart';

/// 保留Mock示例日志，不声明真实书源调试。— Codex + Bridge
final class MockBookSourceDebugService implements BookSourceDebugService {
  const MockBookSourceDebugService();
  @override
  Stream<BookSourceDebugEvent> debug(String sourceUrl, String key) async* {
    yield BookSourceDebugEvent(state: 1, message: '[00:00.000] ⇒开始搜索关键字:$key');
    yield BookSourceDebugEvent(
      state: 1,
      message: '[00:00.010] 书源 URL: $sourceUrl',
    );
    yield const BookSourceDebugEvent(
      state: 1000,
      message: '[00:00.020] ︽Mock 调试完成',
    );
  }

  @override
  Future<void> cancel() async {}
}
