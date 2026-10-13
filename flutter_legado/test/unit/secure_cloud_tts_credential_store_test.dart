import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_legado/src/platform/tts/cloud_tts_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('平台适配只委托安全存储 API，无普通偏好回退', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureCloudTtsCredentialStore();
    await store.write('cloud-tts:fixture:1', 'test-secret');
    expect(await store.read('cloud-tts:fixture:1'), 'test-secret');
    await store.delete('cloud-tts:fixture:1');
    expect(await store.read('cloud-tts:fixture:1'), isNull);
  });
}
