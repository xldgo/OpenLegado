import '../../constants/pref_keys.dart';
import '../../domain/contracts/home_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/home_settings.dart';
import '../services/app_settings_service.dart';

/// 编码原偏好键，持久化、并发和回退统一由共享服务负责。— Codex + UI
final class AppHomeSettingsRepository implements HomeSettingsRepository {
  AppHomeSettingsRepository(this._service);

  final AppSettingsService _service;
  bool _loaded = false;
  Future<HomeSettings>? _loading;

  static const _discovery = (
    storage: SettingsStorageKind.preferences,
    key: PrefKeys.showDiscovery,
  );
  static const _rss = (
    storage: SettingsStorageKind.preferences,
    key: PrefKeys.showRss,
  );
  static const _homePage = (
    storage: SettingsStorageKind.preferences,
    key: PrefKeys.defaultHomePage,
  );
  static const _addresses = {_discovery, _rss, _homePage};

  HomeSettings _decode(AppSettingsSnapshot snapshot) => HomeSettings(
    showDiscovery: switch (snapshot[_discovery]) {
      bool value => value,
      _ => true,
    },
    showRss: switch (snapshot[_rss]) {
      bool value => value,
      _ => true,
    },
    // 未知旧值只在导航时回退，不因为打开页面就改写原存储。
    defaultHomePage: switch (snapshot[_homePage]) {
      String value => value,
      _ => 'bookshelf',
    },
  );

  @override
  HomeSettings get current => _decode(_service.current);

  @override
  Stream<HomeSettings> watch() => _service.watch().map(_decode).distinct();

  @override
  Future<HomeSettings> load() {
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
  Future<void> update({
    bool? showDiscovery,
    bool? showRss,
    String? defaultHomePage,
  }) => _service.update({
    // 初始化前选择默认值也必须保存；显式差量不会覆盖尚未加载的其他字段。
    _discovery: ?showDiscovery,
    _rss: ?showRss,
    _homePage: ?defaultHomePage,
  });

  @override
  Future<void> reload() async {
    await _service.reload(_addresses);
    _loaded = true;
  }

  @override
  Future<void> settled() => _service.settled();
}
