import 'dart:async';

import 'package:flutter_legado/src/platform/audio/app_audio_session.dart';

/// 控制平台响应与中断，断言真实使用凭据和调用顺序。— Codex + UI
final class TestAudioSessionBackend implements AppAudioSessionBackend {
  final source = StreamController<AppAudioEvent>.broadcast(sync: true);
  final activations = <bool>[];
  int configurations = 0;
  bool granted = true;
  Object? configurationError;
  Completer<void>? activationBarrier;

  @override
  Stream<AppAudioEvent> get events => source.stream;
  @override
  Future<void> configure() async {
    configurations++;
    if (configurationError case final error?) throw error;
  }

  @override
  Future<bool> setActive(bool active) async {
    activations.add(active);
    if (active) await activationBarrier?.future;
    return !active || granted;
  }
}
