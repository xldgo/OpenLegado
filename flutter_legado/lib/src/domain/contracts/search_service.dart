import '../../models/models.dart';
import '../models/search_batch.dart';

/// 搜索执行窄接口；原生调度仍由 Rust 拥有。— Codex + Bridge
abstract interface class SearchService {
  Future<List<SearchResult>> searchBooks(
    String keyword, {
    List<String>? sourceUrls,
  });
  Future<SearchBook> preciseSearch(
    String name,
    String author, {
    List<String>? sourceUrls,
  });
  Future<List<Map<String, dynamic>>> searchMulti(
    String query, {
    List<String>? sourceUrls,
  });
  Stream<SearchBatch> searchMultiStream(
    String query, {
    List<String>? sourceUrls,
    int page = 1,
  });
  Future<void> cancelSearch();
  Future<void> pauseSearch();
  Future<void> resumeSearch();
}
