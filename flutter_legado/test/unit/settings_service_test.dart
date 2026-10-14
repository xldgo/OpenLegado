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

  group('SettingsService 亮度', () {
    test('默认亮度为 -1.0（跟随系统）', () async {
      expect(await service.getBrightness(), equals(-1.0));
    });

    test('设置并读取亮度', () async {
      await service.setBrightness(0.8);
      expect(await service.getBrightness(), equals(0.8));
    });
  });

  // [红线清理 2.0.260 | 台账 1-3] 书架统计/最近阅读开关测试随 SettingsService
  // 对应方法一并移除（功能已清理，原版该开关默认关闭）

  group('SettingsService 语言设置', () {
    test('默认语言为 system', () async {
      expect(await service.getLocale(), equals('system'));
    });

    test('设置并读取语言', () async {
      await service.setLocale('zh_CN');
      expect(await service.getLocale(), equals('zh_CN'));
    });
  });

  group('SettingsService 网络设置', () {
    test('代理默认为 none', () async {
      expect(await service.getProxyType(), 'none');
      expect(await service.getProxyHost(), '');
      expect(await service.getProxyPort(), 0);
    });

    test('代理配置读写一致', () async {
      await service.setProxyType('http');
      await service.setProxyHost('127.0.0.1');
      await service.setProxyPort(7890);
      expect(await service.getProxyType(), 'http');
      expect(await service.getProxyHost(), '127.0.0.1');
      expect(await service.getProxyPort(), 7890);
    });

    test('SOCKS5 代理读写一致', () async {
      await service.setProxyType('socks5');
      await service.setProxyHost('192.168.1.10');
      await service.setProxyPort(1080);
      expect(await service.getProxyType(), 'socks5');
      expect(await service.getProxyHost(), '192.168.1.10');
      expect(await service.getProxyPort(), 1080);
    });

    test('请求超时默认 30 秒且读写一致', () async {
      expect(await service.getRequestTimeout(), 30);
      await service.setRequestTimeout(15);
      expect(await service.getRequestTimeout(), 15);
    });
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
