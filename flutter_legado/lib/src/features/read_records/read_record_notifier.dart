import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../bridge/ffi.dart';
import '../../models/models.dart';
import '../../services/settings_service.dart';
import '../../providers/providers.dart';
import 'read_record_repository_provider.dart';
import 'read_record_state.dart';

/// 阅读记录 Riverpod Notifier（对齐原版 ReadRecordActivity）
///
/// 职责：经 ReadRecordRepository 读写 readRecord；搜索/排序在本层完成；
/// 偏好 `enableReadRecord` / `readRecordSort` 经 SettingsService 持久化。
class ReadRecordNotifier extends Notifier<ReadRecordState> {
  final SettingsService _settings = SettingsService();
  int _modeRevision = 0;
  Future<void> _modeWrite = Future.value();

  /// 全量原始记录（未过滤），供搜索重算
  List<ReadRecordShow> _all = const [];

  @override
  ReadRecordState build() => const ReadRecordState();

  /// 加载偏好 + 列表 + 总时长
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final modeRevision = _modeRevision;
      final preferences = await SharedPreferences.getInstance();
      final storedMode = preferences.getString('readRecordDisplayMode');
      final savedMode =
          ReadRecordDisplayMode.values
              .where((m) => m.name == storedMode)
              .firstOrNull ??
          ReadRecordDisplayMode.aggregate;
      final sort = _sortFromRaw(await _settings.getReadRecordSort());
      final enable = await _settings.getEnableReadRecord();
      final repository = ref.read(readRecordRepositoryProvider);
      final raw = await repository.getReadRecords();
      _all = _toShowList(raw);
      final total = _all.fold<int>(0, (sum, r) => sum + r.readTime);
      final filtered = _applyFilterAndSort(_all, state.searchQuery, sort);
      state = state.copyWith(
        records: filtered,
        totalReadTimeMs: total,
        sortMode: sort,
        displayMode: modeRevision == _modeRevision
            ? savedMode
            : state.displayMode,
        enableRecord: enable,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapError(e));
    }
  }

  /// 展示方式即时切换，偏好串行保存避免快速点击时写入顺序颠倒。
  Future<void> setDisplayMode(ReadRecordDisplayMode mode) {
    _modeRevision++;
    state = state.copyWith(displayMode: mode);
    _modeWrite = _modeWrite.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('readRecordDisplayMode', mode.name);
    });
    return _modeWrite;
  }

  void setSelectedDate(DateTime? date) => state = state.copyWith(
    selectedDate: date == null
        ? null
        : DateTime(date.year, date.month, date.day),
    clearSelectedDate: date == null,
  );

  /// 搜索（对齐原版 SearchView onQueryTextChange → initData）
  void setSearchQuery(String query) {
    final q = query.trim();
    state = state.copyWith(
      searchQuery: q,
      records: _applyFilterAndSort(_all, q, state.sortMode),
    );
  }

  /// 切换排序并持久化
  Future<void> setSortMode(ReadRecordSortMode mode) async {
    await _settings.setReadRecordSort(_sortToRaw(mode));
    state = state.copyWith(
      sortMode: mode,
      records: _applyFilterAndSort(_all, state.searchQuery, mode),
    );
  }

  /// 启用/关闭阅读时长记录（对齐菜单 menu_enable_record）
  Future<void> toggleEnableRecord() async {
    final next = !state.enableRecord;
    await _settings.setEnableReadRecord(next);
    state = state.copyWith(enableRecord: next);
  }

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
    final books = await ref
        .read(bookApiProvider)
        .bookshelfRepository
        .getBooks();
    for (final b in books) {
      if (b.name == bookName) return b;
    }
    return null;
  }

  static ReadRecordSortMode _sortFromRaw(int raw) {
    switch (raw) {
      case 1:
        return ReadRecordSortMode.readTime;
      case 2:
        return ReadRecordSortMode.lastRead;
      default:
        return ReadRecordSortMode.name;
    }
  }

  static int _sortToRaw(ReadRecordSortMode mode) {
    switch (mode) {
      case ReadRecordSortMode.readTime:
        return 1;
      case ReadRecordSortMode.lastRead:
        return 2;
      case ReadRecordSortMode.name:
        return 0;
    }
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
