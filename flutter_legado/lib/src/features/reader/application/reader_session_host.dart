import 'reader_state.dart';

/// 读取与发布唯一阅读状态；分页清理由表现层执行。— Codex + UI
final class ReaderSessionHost {
  const ReaderSessionHost({
    required this.readState,
    required this.writeState,
    required this.resetPagination,
  });

  final ReaderState Function() readState;
  final void Function(ReaderState) writeState;
  final void Function() resetPagination;
}
