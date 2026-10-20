import '../../models/models.dart';
import '../models/source_switch_batch.dart';

/// 换源查询与事务入口；匹配、排序、预拉和持久化由Rust负责。— Codex + Bridge
abstract interface class SourceSwitchService {
  Future<List<SourceMatch>> searchSource(
    String bookName,
    String author, {
    List<String>? sourceUrls,
    bool loadInfo = false,
    bool loadToc = false,
    bool loadWordCount = false,
    bool forceRefresh = false,
  });
  Stream<SourceSwitchBatch> searchSourceStream(
    String bookName,
    String author, {
    List<String>? sourceUrls,
    bool loadInfo = false,
    bool loadToc = false,
    bool loadWordCount = false,
    bool forceRefresh = false,
  });
  Future<Book> switchSource(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  );
  Future<Book> switchSourcePrefetch(
    String bookUrl,
    String newSourceUrl,
    String newBookUrl,
  );
  Future<void> cancelSwitchSourceApply();
  Future<void> updateSearchBookScore(String bookUrl, int score);
  Future<void> deleteSearchBook(String bookUrl);
}
