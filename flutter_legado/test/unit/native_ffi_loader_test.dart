import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/native_ffi.dart';

void main() {
  late Directory root;
  late Directory flutter;
  setUp(() {
    root = Directory.systemTemp.createTempSync('legado-native-loader-');
    flutter = Directory('${root.path}/flutter_legado')..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  for (final (platform, name) in [
    ('windows', 'legado_ffi.dll'),
    ('linux', 'liblegado_ffi.so'),
    ('macos', 'liblegado_ffi.dylib'),
  ]) {
    test('$platform只解析当前宿主debug产物', () {
      final file = File('${root.path}/rust/target/debug/$name');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync([1]);
      expect(
        nativeTestLibraryPath(
          environment: {},
          operatingSystem: platform,
          flutterDirectory: flutter,
        ),
        file.resolveSymbolicLinksSync(),
      );
    });
  }

  test('显式路径包含空格与中文时优先使用，缺失不回退默认库', () {
    final explicit = File('${root.path}/构建 空格/ffi.bin');
    explicit.parent.createSync();
    explicit.writeAsBytesSync([1]);
    final environment = {'LEGADO_TEST_FFI_LIBRARY': explicit.path};
    expect(
      nativeTestLibraryPath(environment: environment),
      explicit.resolveSymbolicLinksSync(),
    );
    explicit.deleteSync();
    final defaultLibrary = File(
      '${root.path}/rust/target/debug/legado_ffi.dll',
    );
    defaultLibrary.parent.createSync(recursive: true);
    defaultLibrary.writeAsBytesSync([1]);
    expect(
      () => nativeTestLibraryPath(
        environment: environment,
        operatingSystem: 'windows',
        flutterDirectory: flutter,
      ),
      throwsStateError,
    );
  });

  test('缺失或空库失败，不复用release产物', () {
    final release = File('${root.path}/rust/target/release/legado_ffi.dll');
    release.parent.createSync(recursive: true);
    release.writeAsBytesSync([1]);
    String resolve() => nativeTestLibraryPath(
      environment: {},
      operatingSystem: 'windows',
      flutterDirectory: flutter,
    );
    expect(resolve, throwsStateError);
    final debug = File('${root.path}/rust/target/debug/legado_ffi.dll');
    debug.parent.createSync();
    debug.createSync();
    expect(resolve, throwsStateError);
  });

  test('显式空路径与不支持的宿主返回可定位错误', () {
    expect(
      () => nativeTestLibraryPath(environment: {'LEGADO_TEST_FFI_LIBRARY': ''}),
      throwsStateError,
    );
    expect(
      () => nativeTestLibraryPath(
        environment: {},
        operatingSystem: 'android',
        flutterDirectory: flutter,
      ),
      throwsUnsupportedError,
    );
  });
}
