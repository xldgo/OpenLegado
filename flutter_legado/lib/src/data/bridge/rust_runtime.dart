import 'rust_errors.dart';

import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;

import '../../bridge/rust_lib.dart' as bridge;
import 'runtime_configuration.dart';

/// Bootstrap 使用的原生能力，不决定启动顺序或失败策略。— Codex + Bridge
abstract interface class RustRuntime implements RuntimeConfigurationSink {
  Future<void> initialize();
  Future<void> openDatabase(String path);
  Future<bool> setTtsCacheDirectory(String path);
  Future<void> setJsCacheDirectory(String path);
  Future<void> setImageCacheDirectory(String path);
  Future<void> setAudioCacheDirectory(String path);
  Future<void> setDeviceId(String id);
}

class NativeRustRuntime implements RustRuntime {
  const NativeRustRuntime({this.libraryResolver});

  /// 原生测试可传入显式库，生产沿用原来的搜索及静态加载策略。
  final ExternalLibrary? Function()? libraryResolver;

  @override
  Future<void> initialize() async {
    final library = (libraryResolver ?? _resolveFfiLibrary)();
    await bridge.RustLib.init(externalLibrary: library);
    await rustFuture(() => bridge.init(), operation: 'init');
  }

  @override
  Future<void> openDatabase(String path) =>
      rustFuture(() => bridge.dbOpen(path: path), operation: 'dbOpen');

  @override
  Future<bool> setTtsCacheDirectory(String path) => rustFuture(
    () => bridge.ttsSetCacheDir(path: path),
    operation: 'ttsSetCacheDir',
  );

  @override
  Future<void> setJsCacheDirectory(String path) =>
      rustFuture(() => bridge.setCacheDir(dir: path), operation: 'setCacheDir');

  @override
  Future<void> setImageCacheDirectory(String path) => rustFuture(
    () => bridge.setImageCacheDir(dir: path),
    operation: 'setImageCacheDir',
  );

  @override
  Future<void> setAudioCacheDirectory(String path) => rustFuture(
    () => bridge.setAudioCacheDir(dir: path),
    operation: 'setAudioCacheDir',
  );

  @override
  Future<void> setDeviceId(String id) => rustFuture(
    () => bridge.setDeviceId(deviceId: id),
    operation: 'setDeviceId',
  );

  @override
  Future<void> setThemeConfig(RuntimeConfigSnapshot snapshot) => rustFuture(
    () => bridge.setThemeConfig(themeJson: snapshot.encode()),
    operation: 'setThemeConfig',
  );

  @override
  Future<void> setThemeMode(String mode) => rustFuture(
    () => bridge.setThemeMode(mode: mode),
    operation: 'setThemeMode',
  );

  @override
  Future<void> setReadBookConfig(RuntimeConfigSnapshot snapshot) => rustFuture(
    () => bridge.setReadBookConfig(readJson: snapshot.encode()),
    operation: 'setReadBookConfig',
  );
}

ExternalLibrary? _resolveFfiLibrary() {
  // Android 仍由系统加载；iOS 静态库从进程符号查找。
  if (Platform.isAndroid) return null;
  if (Platform.isIOS) {
    return ExternalLibrary.process(iKnowHowToUseIt: true);
  }

  final String libName;
  if (Platform.isWindows) {
    libName = 'legado_ffi.dll';
  } else if (Platform.isMacOS) {
    libName = 'liblegado_ffi.dylib';
  } else {
    libName = 'liblegado_ffi.so';
  }

  final sep = Platform.pathSeparator;
  final searchPaths = <String>[];
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    searchPaths.add('$exeDir$sep$libName');
    final projectFromExe = File(Platform.resolvedExecutable)
        .parent
        .parent
        .parent
        .parent
        .parent
        .path;
    // 保留 exe 目录优先，以及开发构建 debug 优先的原顺序。
    searchPaths.add(
      '$projectFromExe$sep..${sep}rust${sep}target${sep}debug$sep$libName',
    );
    searchPaths.add(
      '$projectFromExe$sep..${sep}rust${sep}target${sep}release$sep$libName',
    );
  } catch (_) {}

  try {
    final cwd = Directory.current.path;
    searchPaths.add('$cwd$sep..${sep}rust${sep}target${sep}debug$sep$libName');
    searchPaths.add(
      '$cwd$sep..${sep}rust${sep}target${sep}release$sep$libName',
    );
    searchPaths.add('$cwd${sep}rust${sep}target${sep}debug$sep$libName');
    searchPaths.add('$cwd${sep}rust${sep}target${sep}release$sep$libName');
  } catch (_) {}

  for (final path in searchPaths) {
    try {
      if (File(path).existsSync()) return ExternalLibrary.open(path);
    } catch (_) {
      // 库存在但加载失败时继续原搜索流程，最后使用 FRB 默认加载器。
      continue;
    }
  }
  return null;
}
