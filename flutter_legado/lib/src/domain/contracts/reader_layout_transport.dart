import '../models/reader_layout_reply.dart';

/// 传输适配器只处理批量协议；断行和分页只有 Rust 一个实现。
abstract interface class ReaderLayoutTransport {
  Future<ReaderLayoutReply> begin(Map<String, Object?> config);
  Future<ReaderLayoutReply> push(
    Object sessionId,
    List<Map<String, Object?>> blocks,
  );
  Future<ReaderLayoutReply> finish(Object sessionId);
  Future<void> cancel(Object sessionId);
}
