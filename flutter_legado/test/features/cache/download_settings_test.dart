import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/data/repositories/app_download_settings_repository.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/data/settings/shared_preferences_settings_storage.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/domain/models/download_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/home_settings_storage.dart';

void main() {
  test('真实偏好沿用上游键，两个仓储共享更新，重建后保留', () async {
    SharedPreferences.setMockInitialValues({'preDownloadNum': 7, '无关配置': true});
    AppSettingsService service() => AppSettingsService(
      storages: {
        SettingsStorageKind.preferences: SharedPreferencesSettingsStorage(),
      },
    );
    final store = service();
    addTearDown(store.dispose);
    final repository = AppDownloadSettingsRepository(store);
    final reader = AppDownloadSettingsRepository(store);
    expect(await repository.load(), const DownloadSettings(preDownloadNum: 7));
    final changes = <DownloadSettings>[];
    final subscription = reader.watch().listen(changes.add);
    addTearDown(subscription.cancel);
    await repository.update((s) => s.copyWith(preDownloadNumPrev: 100));
    await repository.update((s) => s.copyWith(preDownloadNum: 0));
    await Future<void>.delayed(Duration.zero);
    expect(
      reader.current,
      const DownloadSettings(preDownloadNum: 0, preDownloadNumPrev: 100),
    );
    expect(changes.last, reader.current);
    final rebuilt = service();
    addTearDown(rebuilt.dispose);
    expect(await AppDownloadSettingsRepository(rebuilt).load(), reader.current);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('preDownloadNum'), 0);
    expect(prefs.getInt('preDownloadNumPrev'), 100);
    expect(prefs.getBool('无关配置'), isTrue);
  });

  test('越界拒绝写入，写入失败回退，读取错误可重试', () async {
    final storage = HomeSettingsStorage()..values['preDownloadNum'] = 5;
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(service.dispose);
    final repository = AppDownloadSettingsRepository(service);
    storage.readFailure = true;
    await expectLater(repository.load(), throwsStateError);
    storage.readFailure = false;
    expect((await repository.load()).preDownloadNum, 5);
    for (final value in [-1, 101]) {
      await expectLater(
        repository.update((s) => s.copyWith(preDownloadNum: value)),
        throwsRangeError,
      );
      await expectLater(
        repository.update((s) => s.copyWith(preDownloadNumPrev: value)),
        throwsRangeError,
      );
    }
    expect(storage.writes, isEmpty);
    storage.writeFailure = true;
    await expectLater(
      repository.update((s) => s.copyWith(preDownloadNum: 8)),
      throwsStateError,
    );
    expect(repository.current.preDownloadNum, 5);
    expect(storage.values['preDownloadNum'], 5);
  });

  test('非法存量值只回退快照，读取不自动改写偏好', () async {
    final storage = HomeSettingsStorage()
      ..values.addAll({'preDownloadNum': 999, 'preDownloadNumPrev': '3'});
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(service.dispose);
    final repository = AppDownloadSettingsRepository(service);
    expect(await repository.load(), const DownloadSettings());
    expect(storage.writes, isEmpty);
  });
}
