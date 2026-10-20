import '../../domain/contracts/bookshelf_settings_repository.dart';
import '../../domain/models/bookshelf_settings.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../services/app_settings_service.dart';

/// 保留原偏好编码，委托同一共享设置服务。— Codex + UI
final class AppBookshelfSettingsRepository
    implements BookshelfSettingsRepository {
  AppBookshelfSettingsRepository(this._service);
  final AppSettingsService _service;
  bool _loaded = false;
  Future<BookshelfSettings>? _loading;
  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: key);
  static final _addresses = {
    _address('bookshelf_layout'),
    _address('bookshelf_grid_columns'),
    _address('bookshelf_group_mode'),
    _address('bookshelf_tab_position'),
    _address('openBookInfoByClickTitle'),
    _address('delete_book_alert'),
  };

  T _read<T>(AppSettingsSnapshot snapshot, String key, T fallback) {
    final value = snapshot[_address(key)];
    return value is T ? value : fallback;
  }

  BookshelfSettings _decode(AppSettingsSnapshot snapshot) => BookshelfSettings(
    isGridView: _read(snapshot, 'bookshelf_layout', false),
    gridColumns: _read(snapshot, 'bookshelf_grid_columns', 3).clamp(2, 6),
    groupMode:
        GroupMode.values
            .where(
              (value) =>
                  value.name == _read(snapshot, 'bookshelf_group_mode', ''),
            )
            .firstOrNull ??
        GroupMode.none,
    selectedGroupIndex: _read(snapshot, 'bookshelf_tab_position', 0),
    openBookInfoByClickTitle: _read(
      snapshot,
      'openBookInfoByClickTitle',
      false,
    ),
    deleteBookAlert: _read(snapshot, 'delete_book_alert', true),
  );
  @override
  BookshelfSettings get current => _decode(_service.current);
  @override
  Stream<BookshelfSettings> watch() => _service.watch().map(_decode).distinct();
  @override
  Future<BookshelfSettings> load() {
    if (_loaded) return Future.value(current);
    return _loading ??= _service
        .load(_addresses)
        .then((_) {
          _loaded = true;
          return current;
        })
        .whenComplete(() => _loading = null);
  }

  @override
  Future<void> reload() async {
    await _service.reload(_addresses);
    _loaded = true;
  }

  @override
  Future<void> update({
    bool? isGridView,
    int? gridColumns,
    GroupMode? groupMode,
    int? selectedGroupIndex,
    bool? openBookInfoByClickTitle,
    bool? deleteBookAlert,
  }) => _service.update({
    _address('bookshelf_layout'): ?(isGridView),
    _address('bookshelf_grid_columns'): ?(gridColumns?.clamp(2, 6)),
    _address('bookshelf_group_mode'): ?(groupMode?.name),
    _address('bookshelf_tab_position'): ?(selectedGroupIndex),
    _address('openBookInfoByClickTitle'): ?(openBookInfoByClickTitle),
    _address('delete_book_alert'): ?deleteBookAlert,
  });
}
