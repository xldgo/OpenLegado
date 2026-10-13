import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/models/book_source.dart';

/// 查询夹具覆盖窄接口，其余读写仍使用同一个 Mock 存储。— Codex + UI
final class TestBookSourceRepository implements BookSourceRepository {
  TestBookSourceRepository({
    required this.delegate,
    required this._getBookSources,
  });
  final BookSourceRepository delegate;
  final Future<List<BookSource>> Function() _getBookSources;

  @override
  Future<List<BookSource>> getBookSources() => _getBookSources();
  @override
  Future<List<BookSource>> getEnabledBookSources() =>
      delegate.getEnabledBookSources();
  @override
  Future<BookSource> addBookSource(BookSource source) =>
      delegate.addBookSource(source);
  @override
  Future<void> updateBookSource(BookSource source) =>
      delegate.updateBookSource(source);
  @override
  Future<void> deleteBookSource(String sourceUrl) =>
      delegate.deleteBookSource(sourceUrl);
  @override
  Future<void> enableBookSource(String sourceUrl) =>
      delegate.enableBookSource(sourceUrl);
  @override
  Future<void> disableBookSource(String sourceUrl) =>
      delegate.disableBookSource(sourceUrl);
  @override
  Future<int> importBookSources(String jsonArray) =>
      delegate.importBookSources(jsonArray);
  @override
  Future<String> exportBookSources() => delegate.exportBookSources();
  @override
  Future<void> sortBookSources(int sortKey, bool ascending) =>
      delegate.sortBookSources(sortKey, ascending);
  @override
  Future<void> setSourceVariable(String sourceUrl, String variable) =>
      delegate.setSourceVariable(sourceUrl, variable);
}
