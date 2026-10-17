/// 同步返回的文档原文；不在传输边界解释内部格式。— Codex + Bridge
final class WebDavSyncResult {
  const WebDavSyncResult({required this.books, required this.sources});
  final String books;
  final String sources;
}
