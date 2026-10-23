import '../../bridge/ffi.dart' as bridge;
import '../../bridge/search_aggregate_dto.dart';
import '../../domain/contracts/search_aggregation_service.dart';
import '../../models/search_result.dart';
import '../bridge/rust_errors.dart';

/// 不保留历史输入，只保存Rust确认的新建组首条对象。— Codex + Bridge
final class RustSearchAggregationService implements SearchAggregationService {
  const RustSearchAggregationService();
  @override
  SearchAggregationSession open(String keyword) => _Session(keyword);
}

final class _Session implements SearchAggregationSession {
  _Session(String keyword)
    : _handle = rustFuture(
        () => bridge.searchAggregationBegin(keyword: keyword),
        operation: 'searchAggregationBegin',
      ) {
    _handle.ignore();
  }
  final Future<bridge.SearchAggregation> _handle;
  final _representatives = <int, SearchResult>{};
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  // 异步FFI任务池不保证提交顺序；同一查询按add/snapshot调用顺序执行。
  Future<T> _run<T>(
    Future<T> Function(bridge.SearchAggregation handle) operation,
  ) {
    if (_closing != null) return Future.error(StateError('搜索聚合会话已关闭'));
    final result = _tail.then(
      (_) => rustFuture(
        () async => operation(await _handle),
        operation: 'searchAggregation',
      ),
    );
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> addAll(List<SearchResult> books) => _run((handle) async {
    final retained = await handle.add(
      books: [
        for (final b in books)
          SearchAggregateInputDto(
            name: b.book.name,
            author: b.book.author,
            origin: b.book.origin,
            kind: b.book.kind,
            origins: b.origins.toList(),
            hasReadRecord: b.hasReadRecord,
          ),
      ],
    );
    for (final r in retained) {
      _representatives[r.representativeId.toInt()] =
          books[r.inputIndex.toInt()];
    }
  });
  @override
  Future<List<SearchResult>> snapshot({bool keepOther = true}) =>
      _run((handle) async {
        final result = await handle.snapshot(keepOther: keepOther);
        return [
          for (final r in result)
            _representatives[r.representativeId.toInt()]!.copyWith(
              book: _representatives[r.representativeId.toInt()]!.book.copyWith(
                name: r.name,
                author: r.author,
              ),
              origins: r.origins.toSet(),
              hasReadRecord: r.hasReadRecord,
            ),
        ];
      });
  @override
  Future<void> close() => _closing ??= () async {
    await _tail;
    try {
      await rustFuture(
        () async => (await _handle).close(),
        operation: 'searchAggregationClose',
      );
    } finally {
      _representatives.clear();
    }
  }();
}
