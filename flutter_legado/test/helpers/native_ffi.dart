import 'dart:io';

import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;

/// 原生测试只加载显式指定的库或当前宿主的debug产物，缺失时直接失败。
/// 不沿用生产加载器搜索release或默认库的回退。— Codex + Bridge
String nativeTestLibraryPath({
  Map<String, String>? environment,
  String? operatingSystem,
  Directory? flutterDirectory,
}) {
  final env = environment ?? Platform.environment;
  final configured = env['LEGADO_TEST_FFI_LIBRARY'];
  final String path;
  if (configured != null) {
    if (configured.trim().isEmpty) {
      throw StateError('LEGADO_TEST_FFI_LIBRARY不能为空');
    }
    path = configured;
  } else {
    final name = switch (operatingSystem ?? Platform.operatingSystem) {
      'windows' => 'legado_ffi.dll',
      'linux' => 'liblegado_ffi.so',
      'macos' => 'liblegado_ffi.dylib',
      final other => throw UnsupportedError('原生宿主测试不支持平台：$other'),
    };
    path =
        '${(flutterDirectory ?? Directory.current).path}/../rust/target/debug/$name';
  }
  final file = File(path);
  if (!file.existsSync() || file.lengthSync() == 0) {
    throw StateError(
      '缺少非空原生测试库：${file.absolute.path}。'
      '请先构建当前宿主legado-ffi，或设置LEGADO_TEST_FFI_LIBRARY；不跳过测试。',
    );
  }
  return file.resolveSymbolicLinksSync();
}

ExternalLibrary nativeTestLibrary() =>
    ExternalLibrary.open(nativeTestLibraryPath());

NativeRustRuntime nativeTestRuntime() =>
    NativeRustRuntime(libraryResolver: nativeTestLibrary);
