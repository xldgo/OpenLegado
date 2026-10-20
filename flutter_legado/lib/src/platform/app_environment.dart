import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../services/local_book_store.dart';

enum RuntimeCache { tts, js, image, audio }

/// 获取应用的真实平台信息和目录，不调用 FFI。— Codex + UI
abstract interface class AppEnvironment {
  Future<String> databasePath();
  Future<void> warmLocalBookStore();
  Future<String> cacheDirectory(RuntimeCache cache);
  Future<String?> deviceId();
}

class NativeAppEnvironment implements AppEnvironment {
  const NativeAppEnvironment();

  @override
  Future<String> databasePath() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}${Platform.pathSeparator}legado.db';
    }
    return '${Directory.current.path}${Platform.pathSeparator}legado.db';
  }

  @override
  Future<void> warmLocalBookStore() async {
    LocalBookStore.warmWith(await getApplicationDocumentsDirectory());
  }

  @override
  Future<String> cacheDirectory(RuntimeCache cache) async {
    final base = cache == RuntimeCache.tts
        ? await getApplicationSupportDirectory()
        : await getApplicationCacheDirectory();
    final name = switch (cache) {
      RuntimeCache.tts => 'tts_cache',
      RuntimeCache.js => 'js_cache',
      RuntimeCache.image => 'image_cache',
      RuntimeCache.audio => 'audio_cache',
    };
    final directory = Directory('${base.path}${Platform.pathSeparator}$name');
    if (!directory.existsSync()) directory.createSync(recursive: true);
    return directory.path;
  }

  @override
  Future<String?> deviceId() async {
    if (Platform.isIOS) {
      return (await DeviceInfoPlugin().iosInfo).identifierForVendor;
    }
    // 保留非 iOS 的通道尝试；桌面缺少通道由 Bootstrap 按原策略处理。
    const channel = MethodChannel('legado/device_id');
    return channel.invokeMethod<String>('getAndroidId');
  }
}
