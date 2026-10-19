import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/data/repositories/app_system_bar_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/system_bar_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppSettingsService service;
  late AppSystemBarSettingsRepository repository;

  AppSettingsService createService() {
    final settings = AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    addTearDown(settings.dispose);
    return settings;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = createService();
    repository = AppSystemBarSettingsRepository(service);
  });

  test('默认沉浸开启，加载仅只读', () async {
    expect(await repository.load(), const SystemBarSettings());
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    await repository.update();
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('两项偏好保留原布尔键，并由新实例完整恢复', () async {
    await repository.update(
      transparentStatusBar: false,
      immNavigationBar: false,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      {for (final key in prefs.getKeys()) key: prefs.get(key)},
      {'transparentStatusBar': false, 'immNavigationBar': false},
    );
    expect(
      await AppSystemBarSettingsRepository(createService()).load(),
      repository.current,
    );
  });

  test('异常类型只回退展示，保存指定开关不覆盖其他偏好', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transparentStatusBar', 'false');
    await repository.load();
    expect(repository.current.transparentStatusBar, isTrue);
    expect(repository.current.immNavigationBar, isTrue);
    await repository.update(immNavigationBar: false);
    expect(prefs.getString('transparentStatusBar'), 'false');
    expect(prefs.getBool('immNavigationBar'), isFalse);
  });

  test('订阅只通知系统栏字段变化，不响应其他领域偏好', () async {
    await repository.load();
    final changes = <SystemBarSettings>[];
    final subscription = repository.watch().listen(changes.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);
    expect(changes, [const SystemBarSettings()]);
    await service.update({
      (storage: SettingsStorageKind.preferences, key: 'showDiscovery'): false,
    });
    await Future<void>.delayed(Duration.zero);
    expect(changes, hasLength(1));
    await repository.update(immNavigationBar: false);
    await Future<void>.delayed(Duration.zero);
    expect(changes, [
      const SystemBarSettings(),
      const SystemBarSettings(immNavigationBar: false),
    ]);
  });
}
