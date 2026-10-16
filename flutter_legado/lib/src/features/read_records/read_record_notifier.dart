import '../bookshelf/bookshelf_repositories.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../bridge/ffi.dart';
import '../../models/models.dart';
import '../../domain/contracts/read_record_settings_repository.dart';
import '../../providers/read_record_settings_provider.dart';
import 'read_record_repository_provider.dart';
import 'read_record_state.dart';

/// 阅读记录 Riverpod Notifier（对齐原版 ReadRecordActivity）
///
/// 职责：经 ReadRecordRepository 读写 readRecord；搜索/排序在本层完成；
/// 普通偏好经共享 ReadRecordSettingsRepository 访问。
class ReadRecordNotifier extends Notifier<ReadRecordState> {
  int _preferencesGeneration = 0;

  /// 全量原始记录（未过滤），供搜索重算
  List<ReadRecordShow> _all = const [];

  @override
  ReadRecordState build() {
    final repository = ref.watch(readRecordSettingsRepositoryProvider);
    final generation = ++_preferencesGeneration;
    final subscription = repository.watch().listen(
      (_) => _publishPreferences(repository, generation),
    );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return ReadRecordState(
      enableRecord: repository.current.enableRecord,
      displayMode: repository.current.displayMode,
      sortMode: repository.current.sortMode,
    );
  }

  void _publishPreferences(
    ReadRecordSettingsRepository repository,
    int generation,
  ) {
    if (!ref.mounted || generation != _preferencesGeneration) return;
    final settings = repository.current;
    state = state.copyWith(
      enableRecord: settings.enableRecord,
      displayMode: settings.displayMode,
      sortMode: settings.sortMode,
      records: _applyFilterAndSort(_all, state.searchQuery, settings.sortMode),
    );
  }

  Future<void> _savePreferences(
    Future<void> Function(ReadRecordSettingsRepository) save,
  ) async {
    final repository = ref.read(readRecordSettingsRepositoryProvider);
    final generation = _preferencesGeneration;
    try {
      final saving = save(repository);
      _publishPreferences(repository, generation);
      await saving;
    } finally {
      _publishPreferences(repository, generation);
    }
  }

  /// 加载偏好 + 列表 + 总时长
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final preferences = ref.read(readRecordSettingsRepositoryProvider);
      await preferences.load();
      final repository = ref.read(readRecordRepositoryProvider);
      final raw = await repository.getReadRecords();
      _all = _toShowList(raw);
      final total = _all.fold<int>(0, (sum, r) => sum + r.readTime);
      final settings = preferences.current;
      final filtered = _applyFilterAndSort(
        _all,
        state.searchQuery,
        settings.sortMode,
      );
      state = state.copyWith(
        records: filtered,
        totalReadTimeMs: total,
        sortMode: settings.sortMode,
        displayMode: settings.displayMode,
        enableRecord: settings.enableRecord,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapError(e));
    }
  }

  /// 展示偏好通过共享仓储即时生效，保存失败回退。
  Future<void> setDisplayMode(ReadRecordDisplayMode mode) =>
      _savePreferences((repository) => repository.update(displayMode: mode));

  /// 搜索（对齐原版 SearchView onQueryTextChange → initData）
  void setSearchQuery(String query) {
    final q = query.trim();
    state = state.copyWith(
      searchQuery: q,
      records: _applyFilterAndSort(_all, q, state.sortMode),
    );
  }

  /// 切换排序并持久化。
  Future<void> setSortMode(ReadRecordSortMode mode) =>
      _savePreferences((repository) => repository.update(sortMode: mode));

  /// 启用/关闭阅读时长记录，与阅读器共享同一来源。
  Future<void> toggleEnableRecord() => _savePreferences(
    (repository) =>
        repository.update(enableRecord: !repository.current.enableRecord),
  );

  /// 删除单本书记录（对齐 deleteByName）
  Future<void> deleteByName(String bookName) async {
    try {
      await ref.read(readRecordRepositoryProvider).deleteReadRecord(bookName);
      await load();
    } catch (e) {
      state = state.copyWith(error: _mapError(e));
    }
  }

  /// 清空全部（对齐 clear）
  Future<void> clearAll() async {
    try {
      await ref.read(readRecordRepositoryProvider).clearReadRecords();
      await load();
    } catch (e) {
      state = state.copyWith(error: _mapError(e));
    }
  }

  /// 按书名在书架查找（对齐 bookDao.findByName(...).firstOrNull）
  Future<Book?> findBookByName(String bookName) async {
    final books = await ref.read(bookshelfRepositoryProvider).getBooks();
    for (final b in books) {
      if (b.name == bookName) return b;
    }
    return null;
  }

  /// ReadRecord → ReadRecordShow；同名合并时长（对齐 Room group by bookName）
  static List<ReadRecordShow> _toShowList(List<ReadRecord> raw) {
    final map = <String, ReadRecordShow>{};
    for (final r in raw) {
      final prev = map[r.bookName];
      if (prev == null) {
        map[r.bookName] = ReadRecordShow(
          bookName: r.bookName,
          readTime: r.readTime,
          lastRead: r.lastRead,
        );
      } else {
        map[r.bookName] = prev.copyWith(
          readTime: prev.readTime + r.readTime,
          lastRead: r.lastRead > prev.lastRead ? r.lastRead : prev.lastRead,
        );
      }
    }
    return map.values.toList();
  }

  static List<ReadRecordShow> _applyFilterAndSort(
    List<ReadRecordShow> source,
    String query,
    ReadRecordSortMode sort,
  ) {
    var list = source;
    if (query.isNotEmpty) {
      final lower = query.toLowerCase();
      list = list
          .where((r) => r.bookName.toLowerCase().contains(lower))
          .toList();
    } else {
      list = List<ReadRecordShow>.from(list);
    }
    switch (sort) {
      case ReadRecordSortMode.readTime:
        list.sort((a, b) => b.readTime.compareTo(a.readTime));
      case ReadRecordSortMode.lastRead:
        list.sort((a, b) => b.lastRead.compareTo(a.lastRead));
      case ReadRecordSortMode.name:
        list.sort((a, b) => a.bookName.compareTo(b.bookName));
    }
    return list;
  }

  String _mapError(Object e) {
    if (e is BridgeError) return e.message;
    return e.toString();
  }
}

final readRecordNotifierProvider =
    NotifierProvider<ReadRecordNotifier, ReadRecordState>(
      ReadRecordNotifier.new,
    );
