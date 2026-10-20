import 'dart:async';

import '../../../platform/tts/system_tts.dart';
import 'read_aloud_engine.dart';

/// 系统播放适配；原生停止屏障、分片和暂停恢复继续由平台服务实现。— Codex + UI
final class SystemReadAloudEngine implements ReadAloudEngine {
  SystemReadAloudEngine(this._system);

  final SystemTts _system;
  ReadAloudSession? _session;

  @override
  bool get canResume => _system.isPaused;

  void _bind(ReadAloudSession session) {
    _session?.cancel();
    _session = session;
    _system.onProgress = (start, end) => session.reportProgress(start);
  }

  void _observe(Future<SystemTtsOutcome> speech, ReadAloudSession session) {
    unawaited(
      speech.then((outcome) {
        if (outcome == SystemTtsOutcome.completed) {
          session.complete();
        } else {
          session.cancel();
        }
      }, onError: (Object error, StackTrace stack) => session.fail(error)),
    );
  }

  @override
  Future<ReadAloudStart> speak(
    ReadAloudRequest request,
    ReadAloudSession session,
  ) async {
    if (!session.isCurrent) return ReadAloudStart.cancelled;
    _bind(session);
    _observe(
      Future.sync(
        () => _system.speak(
          request.text,
          speed: request.speed,
          pitch: request.pitch,
          volume: request.volume,
        ),
      ),
      session,
    );
    return ReadAloudStart.started;
  }

  @override
  Future<ReadAloudStart> resume(ReadAloudSession session) async {
    if (!session.isCurrent) return ReadAloudStart.cancelled;
    _bind(session);
    _observe(Future.sync(_system.resume), session);
    return ReadAloudStart.started;
  }

  @override
  Future<void> pause() {
    _session?.cancel();
    return _system.pause();
  }

  @override
  Future<void> stop() {
    _session?.cancel();
    _session = null;
    return _system.stop();
  }

  /// 保持原 AudioNotifier 的资源所有权，不给平台 Provider 新增销毁钩子。
  Future<void> dispose() {
    _session?.cancel();
    _session = null;
    return _system.dispose();
  }
}
