/// 已成功提交的业务恢复统计，不包含偏好设置恢复结果。
final class BackupRestoreStats {
  const BackupRestoreStats({
    required this.books,
    required this.bookmarks,
    required this.replaceRules,
    required this.bookSources,
    required this.rssSources,
    required this.readRecords,
  });

  final int books;
  final int bookmarks;
  final int replaceRules;
  final int bookSources;
  final int rssSources;
  final int readRecords;
}
