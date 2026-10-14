import '../../domain/contracts/search_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/search_settings.dart';
import '../services/app_settings_service.dart';

/// 只投影同一服务的快照；不另存搜索设置状态或维护写队列。— Codex + UI
final class AppSearchSettingsRepository implements SearchSettingsRepository {
  AppSearchSettingsRepository(this._service);
  final AppSettingsService _service;

  static const _precision = (
    storage: SettingsStorageKind.rustConfig,
    key: 'precisionSearch',
  );
  static const _filter = (
    storage: SettingsStorageKind.rustConfig,
    key: 'searchResultFilter',
  );
  static const _scope = (
    storage: SettingsStorageKind.rustConfig,
    key: 'searchScope',
  );
  static const _group = (
    storage: SettingsStorageKind.rustConfig,
    key: 'searchGroup',
  );
  static const _readRecord = (
    storage: SettingsStorageKind.preferences,
    key: 'showSearchReadRecord',
  );
  static const _addresses = {_precision, _filter, _scope, _group, _readRecord};
  static const _rustAddresses = {_precision, _filter, _scope, _group};

  SearchSettings _decode(AppSettingsSnapshot snapshot) => SearchSettings(
    precisionSearch: snapshot[_precision] == 'true',
    resultFilter: (snapshot[_filter] as String? ?? '').trim(),
    scope: (snapshot[_scope] as String? ?? '').trim(),
    searchGroup: snapshot[_group] as String? ?? '',
    showReadRecord: snapshot[_readRecord] as bool? ?? false,
  );

  Map<SettingsAddress, Object?> _encode(SearchSettings settings) => {
    _precision: settings.precisionSearch ? 'true' : 'false',
    _filter: settings.resultFilter,
    _scope: settings.scope,
    _group: settings.searchGroup,
    _readRecord: settings.showReadRecord,
  };

  @override
  SearchSettings get current => _decode(_service.current);

  @override
  Stream<SearchSettings> watch() => _service.watch().map(_decode).distinct();

  @override
  Future<SearchSettings> load() async {
    await _service.load(_addresses);
    return current;
  }

  @override
  Future<void> loadRuntime() => _service.load(_rustAddresses);

  @override
  Future<void> update(SearchSettings Function(SearchSettings) transform) {
    final previous = current;
    final next = transform(previous);
    final before = _encode(previous);
    final after = _encode(next);
    return _service.update({
      for (final entry in after.entries)
        if (before[entry.key] != entry.value) entry.key: entry.value,
    });
  }

  @override
  Future<void> reload() => _service.reload(_addresses);

  @override
  Future<void> reloadRuntime() => _service.reload(_rustAddresses);

  @override
  Future<void> settled() => _service.settled();
}
