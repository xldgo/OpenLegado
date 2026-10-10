import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/services/app_update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('应用版本读取使用 PackageInfo 并保留进程内缓存', () async {
    PackageInfo.setMockInitialValues(
      appName: 'OpenLegado',
      packageName: 'io.legado.flutter_legado',
      version: '2.0.369',
      buildNumber: '370',
      buildSignature: '',
    );
    expect(await AppUpdateService.resolveCurrentVersionName(), '2.0.369');
    PackageInfo.setMockInitialValues(
      appName: 'OpenLegado',
      packageName: 'io.legado.flutter_legado',
      version: '9.9.9',
      buildNumber: '999',
      buildSignature: '',
    );
    expect(await AppUpdateService.resolveCurrentVersionName(), '2.0.369');
  });

  group('AppUpdate version helpers', () {
    test('normalizeLegadoVersionName', () {
      expect(normalizeLegadoVersionName('3.23.080312'), '3.23080312');
      expect(normalizeLegadoVersionName('3.26080322'), '3.26080322');
      expect(normalizeLegadoVersionName('2.0.38'), '2.0.38');
    });

    test('compareReleaseVersions', () {
      expect(compareReleaseVersions('2.0.39', '2.0.38'), greaterThan(0));
      expect(compareReleaseVersions('2.0.38', '2.0.38'), 0);
      expect(compareReleaseVersions('2.0.37', '2.0.38'), lessThan(0));
    });

    test('CDN / backup URL', () {
      expect(
        resolveAppUpdateDownloadUrl('app.apk', 'https://gh/app.apk'),
        'https://cdn.mgz.la/app/app.apk',
      );
      expect(
        resolveAppUpdateDownloadUrl('app_._.apk', 'https://gh/app_._.apk'),
        'https://gh/app_._.apk',
      );
      expect(
        resolveAppUpdateBackupUrl(
          'https://cdn.mgz.la/app/a.apk',
          'https://gh/a.apk',
        ),
        'https://gh/a.apk',
      );
      expect(
        resolveAppUpdateBackupUrl('https://gh/a.apk', 'https://gh/a.apk'),
        isNull,
      );
    });

    test('inferAppVariant', () {
      expect(
        inferAppVariant('legado_app_release.apk', false),
        AppVariant.betaRelease,
      );
      expect(
        inferAppVariant('legado_app_releaseA.apk', false),
        AppVariant.betaReleaseA,
      );
      expect(inferAppVariant('legado.apk', false), AppVariant.official);
    });
  });
}
