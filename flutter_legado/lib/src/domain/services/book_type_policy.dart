import '../../models/models.dart';

/// 书籍媒体位与详情快照合并，不识别书源或决定导航。— Codex + UI
class BookTypePolicy {
  BookTypePolicy._();

  /// 媒体/文本类型位掩码（不含 local / notShelf）
  static const int typeMask =
      BookType.video |
      BookType.text |
      BookType.audio |
      BookType.image |
      BookType.webFile;

  /// [P2-15 ② | type 回流 2026-09-18] 详情解析 type（WebBookInfo JSON
  /// `type` 键，BookType 位标记）并入书籍 bookType。
  ///
  /// 覆盖语义（对齐上游 analyzeBookInfo：详情解析是书籍模式的权威来源——
  /// JS `book.type=N` 写路径值 > 书源声明值）：
  /// - [fresh] 非零 → 覆盖现有**媒体位**（[typeMask] 内），非媒体标记位
  ///   （local / notShelf / updateError 等）原样保留；
  /// - [fresh] 为 0（含 Rust 侧零值省略不序列化、缺键）→ 保留现有值，
  ///   不用空覆盖。
  ///
  /// 已知风险（与上游一致的取舍）：用户侧若手动改过书籍模式，下次详情
  /// 进入/刷新时 JS `book.type` 写值会再次覆盖（JS 胜出）；本应用当前
  /// 无手动改模式 UI，风险仅对未来功能面。
  static int mergeBookType(int existing, int fresh) {
    final freshBits = fresh & typeMask;
    if (freshBits == 0) return existing;
    return (existing & ~typeMask) | freshBits;
  }
}
