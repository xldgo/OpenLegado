/// 旧版文件导入的实际统计与逐文件消息。— Codex + Bridge
final class OldDataImportResult {
  const OldDataImportResult({
    required this.books,
    required this.bookSources,
    required this.replaceRules,
    required this.messages,
  });
  final int books;
  final int bookSources;
  final int replaceRules;
  final List<String> messages;
}
