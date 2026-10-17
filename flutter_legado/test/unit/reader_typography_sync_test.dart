import '../fixtures/app_test_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/association/association_notifier.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';

import '../fixtures/home_settings_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HomeSettingsStorage storage;
  late AppSettingsService service;
  late ProviderContainer container;
  late SettingsRuntimeConfiguration source;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = HomeSettingsStorage()
      ..values.addAll({'reader_font_size': 22.0, 'reader_line_height': 1.8});
    service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        appSettingsServiceProvider.overrideWithValue(service),
      ]),
    );
    source = SettingsRuntimeConfiguration(
      appSettings: service,
      readerSettings: container.read(readerSettingsRepositoryProvider),
    );
    container.read(readerNotifierProvider);
    await source.readReadBookConfig();
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await service.dispose();
  });

  test('主题导入同步已打开阅读器与书源快照，缺省字段保持原值', () async {
    final importer = container.read(associationNotifierProvider.notifier);
    var result = await importer.confirmImport(ImportType.theme, [
      {'fontSize': 26, 'lineHeight': 2.2},
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(result.success, 1);
    expect(result.failed, 0);
    expect(container.read(readerNotifierProvider).fontSize, 26);
    expect(container.read(readerNotifierProvider).lineHeight, 2.2);
    expect((await source.readReadBookConfig()).fields['textSize'], 26);
    result = await importer.confirmImport(ImportType.theme, [
      {'fontSize': 27},
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(result.success, 1);
    expect(container.read(readerNotifierProvider).fontSize, 27);
    expect(container.read(readerNotifierProvider).lineHeight, 2.2);
    expect(storage.values['reader_font_size'], 27.0);
    expect(storage.values['reader_line_height'], 2.2);
    expect(
      (await SharedPreferences.getInstance()).get('reader_font_size'),
      isNull,
    );
  });

  test('导入保存失败返回失败项并回退显示，重试成功', () async {
    storage.writeFailure = true;
    final importer = container.read(associationNotifierProvider.notifier);
    var result = await importer.confirmImport(ImportType.theme, [
      {'fontSize': 26},
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(result.success, 0);
    expect(result.failed, 1);
    expect(result.errors.single, contains('模拟保存失败'));
    expect(container.read(readerNotifierProvider).fontSize, 22);
    expect((await source.readReadBookConfig()).fields['textSize'], 22);
    storage.writeFailure = false;
    result = await importer.confirmImport(ImportType.theme, [
      {'fontSize': 26},
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(result.success, 1);
    expect(container.read(readerNotifierProvider).fontSize, 26);
  });

  test('恢复重读更新字号行距并保持旧快照，修改失败不留下错误注入值', () async {
    final before = await source.readReadBookConfig();
    storage.values.addAll({
      'reader_font_size': 25.6,
      'reader_line_height': 2.1,
    });
    await container.read(readerSettingsRepositoryProvider).reload();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(readerNotifierProvider).fontSize, 25.6);
    expect(container.read(readerNotifierProvider).lineHeight, 2.1);
    expect((await source.readReadBookConfig()).fields['textSize'], 26);
    expect(before.fields['textSize'], 22);
    storage.writeFailure = true;
    await expectLater(
      container.read(readerNotifierProvider.notifier).updateFontSize(30),
      throwsStateError,
    );
    expect(container.read(readerNotifierProvider).fontSize, 25.6);
    expect((await source.readReadBookConfig()).fields['textSize'], 26);
    expect((await source.readReadBookConfig()).fields['lineSpacingExtra'], 8);
  });
}
