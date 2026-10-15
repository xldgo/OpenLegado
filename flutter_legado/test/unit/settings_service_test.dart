import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = SettingsService();
  });

  group('SettingsService WebDAV 云同步配置', () {
    test('默认 WebDAV URL 为空', () async {
      expect(await service.getWebDavUrl(), equals(''));
    });

    test('设置并读取 WebDAV URL', () async {
      await service.setWebDavUrl('https://dav.example.com');
      expect(await service.getWebDavUrl(), equals('https://dav.example.com'));
    });

    test('默认用户名为空', () async {
      expect(await service.getWebDavUsername(), equals(''));
    });

    test('设置并读取用户名', () async {
      await service.setWebDavUsername('user@test.com');
      expect(await service.getWebDavUsername(), equals('user@test.com'));
    });

    test('默认密码为空', () async {
      expect(await service.getWebDavPassword(), equals(''));
    });

    test('设置并读取密码', () async {
      await service.setWebDavPassword('secret123');
      expect(await service.getWebDavPassword(), equals('secret123'));
    });

    test('默认远程目录为 /legado/', () async {
      expect(await service.getWebDavRemoteDir(), equals('/legado/'));
    });

    test('设置并读取远程目录', () async {
      await service.setWebDavRemoteDir('/backup/legado/');
      expect(await service.getWebDavRemoteDir(), equals('/backup/legado/'));
    });

    test('默认自动同步关闭', () async {
      expect(await service.getAutoSync(), isFalse);
    });

    test('开启自动同步', () async {
      await service.setAutoSync(true);
      expect(await service.getAutoSync(), isTrue);
    });

    test('默认无最后同步时间', () async {
      expect(await service.getLastSyncTime(), isNull);
    });

    test('设置并读取最后同步时间', () async {
      final now = DateTime.now();
      await service.setLastSyncTime(now);
      final result = await service.getLastSyncTime();
      expect(result, isNotNull);
      // 毫秒精度比较
      expect(
        result!.millisecondsSinceEpoch,
        equals(now.millisecondsSinceEpoch),
      );
    });
  });
}
