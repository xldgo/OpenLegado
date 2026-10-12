import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/eye_protection.dart';

class EyeProtectionNotifier extends Notifier<EyeProtectionSettings> {
  bool _modified = false;
  bool _disposed = false;
  Future<void> _writes = Future.value();

  @override
  EyeProtectionSettings build() {
    ref.onDispose(() => _disposed = true);
    unawaited(
      Future.microtask(() async {
        final prefs = await SharedPreferences.getInstance();
        if (!_disposed && !_modified) state = EyeProtectionSettings.load(prefs);
      }),
    );
    return const EyeProtectionSettings();
  }

  void update(EyeProtectionSettings settings) {
    _modified = true;
    state = settings;
    // 强度连续拖动时按顺序写入，避免迟到的旧值覆盖最终值。
    _writes = _writes
        .then((_) async {
          await settings.save(await SharedPreferences.getInstance());
        })
        .catchError((Object error) => debugPrint('保存护眼设置失败：$error'));
  }
}

final eyeProtectionProvider =
    NotifierProvider<EyeProtectionNotifier, EyeProtectionSettings>(
      EyeProtectionNotifier.new,
    );
