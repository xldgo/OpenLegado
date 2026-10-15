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

  group('SettingsService 同步偏好与时间', () {
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
