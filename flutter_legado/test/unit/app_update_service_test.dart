import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/services/app_update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> release({
  String version = '2.0.439',
  int build = 10002,
  bool alpha = false,
  bool draft = false,
  List<String> targets = const ['android-arm64-v8a.apk', 'android-x86_64.apk'],
}) {
  final tag = 'v$version${alpha ? '-alpha.$build' : ''}';
  return {
    'tag_name': tag,
    'prerelease': alpha,
    'draft': draft,
    'body': '更新说明',
    'html_url': '${AppUpdateService.projectUrl}/releases/tag/$tag',
    'assets': [
      for (final target in targets)
        {
          'name': 'OpenLegado-$version+$build-$target',
          'state': 'uploaded',
          // GitHub的APK也可能标为octet-stream，不能据此丢弃。
          'content_type': 'application/octet-stream',
          'browser_download_url':
              '${AppUpdateService.projectUrl}/releases/download/$tag/$target',
        },
    ],
  };
}

AppUpdateService service(List<Object?> releases) => AppUpdateService(
  client: MockClient((request) async {
    expect(request.url.toString(), AppUpdateService.releasesUrl);
    return http.Response(
      jsonEncode(releases),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

Future<AppUpdateInfo?> check(
  AppUpdateService updates, {
  bool alpha = true,
  String version = '2.0.439',
  int build = 10001,
  AppUpdateTarget target = AppUpdateTarget.androidArm64,
}) => updates.check(
  currentVersion: version,
  currentBuildNumber: build,
  includePrereleases: alpha,
  target: target,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('应用身份来自PackageInfo并保留进程内缓存', () async {
    PackageInfo.setMockInitialValues(
      appName: 'OpenLegado',
      packageName: 'io.legado.flutter_legado',
      version: '2.0.439',
      buildNumber: '440',
      buildSignature: '',
    );
    expect(await AppUpdateService.resolveCurrentVersionName(), '2.0.439');
    expect((await AppUpdateService.resolveCurrentPackage()).buildNumber, '440');
    PackageInfo.setMockInitialValues(
      appName: 'OpenLegado',
      packageName: 'io.legado.flutter_legado',
      version: '9.9.9',
      buildNumber: '999',
      buildSignature: '',
    );
    expect(await AppUpdateService.resolveCurrentVersionName(), '2.0.439');
  });

  test('测试版选择持久化；开关只控制候选范围，下载使用对应ABI的GitHub地址', () async {
    final updates = service([
      release(build: 10003, alpha: true),
      release(build: 10002),
      release(version: '9.0.0', draft: true),
    ]);
    expect(
      await updates.acceptsPrereleases(),
      AppUpdateService.buildChannel != 'stable',
    );
    await updates.setAcceptsPrereleases(false);
    expect(await service([]).acceptsPrereleases(), isFalse);
    final stable = await check(
      updates,
      alpha: await updates.acceptsPrereleases(),
    );
    expect(stable!.buildNumber, 10002);
    expect(stable.isPrerelease, isFalse);
    await updates.setAcceptsPrereleases(true);
    final alpha = await check(updates, target: AppUpdateTarget.androidX64);
    expect(alpha!.tagName, 'v2.0.439-alpha.10003');
    expect(alpha.fileName, 'OpenLegado-2.0.439+10003-android-x86_64.apk');
    expect(alpha.downloadUrl, endsWith('/android-x86_64.apk'));
  });

  test('版本按数字比较，同版本只接受更高构建；不回退旧版本', () async {
    final updates = service([
      release(version: '2.0.438', build: 99999),
      release(build: 10001),
      release(version: '2.0.9', build: 99999),
    ]);
    expect(await check(updates), isNull);
    expect((await check(updates, build: 440))!.buildNumber, 10001);
    expect(
      await check(service([release(version: '2.0.440', build: 10000)])),
      isNull,
    );
    final newer = service([release(version: '2.0.440', build: 10004)]);
    expect((await check(newer))!.version, '2.0.440');
  });

  test('关闭测试版不会降级；无正式版、无当前平台附件与检查失败分别报告', () async {
    await expectLater(
      check(service([release(alpha: true)]), alpha: false),
      throwsStateError,
    );
    final windows = service([
      release(targets: ['windows-x64.zip']),
    ]);
    await expectLater(check(windows), throwsStateError);
    expect(
      (await check(windows, target: AppUpdateTarget.windowsX64))!.fileName,
      endsWith('windows-x64.zip'),
    );
    final failed = AppUpdateService(
      client: MockClient((_) async => http.Response('Forbidden', 403)),
    );
    await expectLater(check(failed), throwsStateError);
    final malformed = AppUpdateService(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await expectLater(check(malformed), throwsFormatException);
  });

  test('测试版占满首页时仍按分页链接查找正式版', () async {
    final requests = <Uri>[];
    final updates = AppUpdateService(
      client: MockClient((request) async {
        requests.add(request.url);
        final first = requests.length == 1;
        return http.Response(
          jsonEncode([first ? release(alpha: true) : release()]),
          200,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            if (first) 'link': '<https://api.github.com/repos/xldgo/OpenLegado/releases?per_page=100&page=2>; rel="next"',
          },
        );
      }),
    );
    expect((await check(updates, alpha: false))!.isPrerelease, isFalse);
    expect(requests.last.queryParameters['page'], '2');
  });

  test('不接受错标渠道、标签与附件构建不一致及旧原版附件', () async {
    final wrongFlag = release(alpha: true)..['prerelease'] = false;
    final wrongBuild = release(alpha: true)
      ..['tag_name'] = 'v2.0.439-alpha.20000';
    final legacy = release()
      ..['assets'] = [
        {'name': 'legado_app_release.apk', 'state': 'uploaded'},
      ];
    final updates = service([
      wrongFlag,
      wrongBuild,
      legacy,
      release(build: 10001),
    ]);
    expect(await check(updates), isNull);
  });
}
