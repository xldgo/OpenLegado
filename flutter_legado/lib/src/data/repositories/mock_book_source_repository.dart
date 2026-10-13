import 'dart:convert';

import '../../domain/contracts/book_source_repository.dart';
import '../../models/book_source.dart';

/// 默认种子、配置访问与校验共用的唯一 Mock 源存储。— Codex + Bridge
final class MockBookSourceStore {
  final List<BookSource> sources = [];
}

/// 原 Mock 数据访问语义；配置写入共用装配点提供的存储。
final class MockBookSourceRepository implements BookSourceRepository {
  MockBookSourceRepository({
    MockBookSourceStore? store,
    required this._writeConfig,
  }) : _store = store ?? MockBookSourceStore();
  final MockBookSourceStore _store;
  final void Function(String key, String value) _writeConfig;

  @override
  Future<List<BookSource>> getBookSources() async => List.from(_store.sources);

  @override
  Future<List<BookSource>> getEnabledBookSources() async =>
      _store.sources.where((s) => s.enabled).toList();

  @override
  Future<BookSource> addBookSource(BookSource source) async {
    _store.sources.add(source);
    return source;
  }

  @override
  Future<void> updateBookSource(BookSource source) async {
    final idx = _store.sources.indexWhere(
      (s) => s.bookSourceUrl == source.bookSourceUrl,
    );
    if (idx >= 0) _store.sources[idx] = source;
  }

  /// 设置书源自定义变量（契约 §2.3，台账 §5.11-3，Task #63 冻结 / #64-65 实现）
  ///
  /// Mock：短延迟模拟 FFI 往返；命中内存书源时同步回写 variable 字段
  /// （空串=清除，对齐 Rust 单列 UPDATE 语义）；书源不存在时抛错，
  /// 对齐 Rust Internal 语义（评审 S1） — Qoder
  @override
  Future<void> setSourceVariable(String sourceUrl, String variable) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _store.sources.indexWhere((s) => s.bookSourceUrl == sourceUrl);
    if (idx < 0) {
      throw Exception('书源不存在: $sourceUrl');
    }
    _store.sources[idx] = _store.sources[idx].copyWith(variable: variable);
  }

  @override
  Future<void> deleteBookSource(String sourceUrl) async {
    _store.sources.removeWhere((s) => s.bookSourceUrl == sourceUrl);
  }

  @override
  Future<void> enableBookSource(String sourceUrl) async {
    final idx = _store.sources.indexWhere((s) => s.bookSourceUrl == sourceUrl);
    if (idx >= 0) {
      _store.sources[idx] = _store.sources[idx].copyWith(enabled: true);
    }
  }

  @override
  Future<void> disableBookSource(String sourceUrl) async {
    final idx = _store.sources.indexWhere((s) => s.bookSourceUrl == sourceUrl);
    if (idx >= 0) {
      _store.sources[idx] = _store.sources[idx].copyWith(enabled: false);
    }
  }

  @override
  Future<int> importBookSources(String jsonArray) async {
    final list = jsonDecode(jsonArray) as List<dynamic>;
    return list.length;
  }

  @override
  Future<String> exportBookSources() async =>
      jsonEncode(_store.sources.map((s) => s.toJson()).toList());

  @override
  Future<void> sortBookSources(int sortKey, bool ascending) async {
    _writeConfig('source_sort_key', sortKey.toString());
    _writeConfig('source_sort_ascending', ascending.toString());
  }
}
