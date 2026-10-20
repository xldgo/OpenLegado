import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// 语音中断与路由事件；恢复只是许可，是否续播由各播放会话判断。— Codex + UI
enum AppAudioEvent { pause, resume, stop, loss }

/// iOS 开始中断统一报告 unknown，是否允许恢复只在结束时给出；
/// Android unknown 则对应永久失焦，不能据后续 gain 自动续播。— Codex + UI
AppAudioEvent mapAudioInterruption(
  AudioInterruptionEvent event, {
  required bool isAndroid,
}) {
  if (!event.begin) {
    return event.type == AudioInterruptionType.unknown
        ? AppAudioEvent.stop
        : AppAudioEvent.resume;
  }
  return isAndroid && event.type == AudioInterruptionType.unknown
      ? AppAudioEvent.loss
      : AppAudioEvent.pause;
}

/// 平台缝隙用于行为测试；Windows 继续使用现有播放器，不虚构系统焦点能力。
abstract interface class AppAudioSessionBackend {
  Stream<AppAudioEvent> get events;
  Future<void> configure();
  Future<bool> setActive(bool active);
}

final class PluginAudioSessionBackend implements AppAudioSessionBackend {
  Future<AudioSession> get _session => AudioSession.instance;
  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Stream<AppAudioEvent> get events async* {
    if (!_supported) return;
    final session = await _session;
    final events = StreamController<AppAudioEvent>();
    final interruption = session.interruptionEventStream.listen((event) {
      // 连续语音不降音量掩盖正文；duck 与 pause 均暂停，unknown 不自动恢复。
      events.add(mapAudioInterruption(event, isAndroid: Platform.isAndroid));
    }, onError: events.addError);
    final noisy = session.becomingNoisyEventStream.listen((_) {
      events.add(AppAudioEvent.stop);
    }, onError: events.addError);
    try {
      yield* events.stream;
    } finally {
      await interruption.cancel();
      await noisy.cancel();
      await events.close();
    }
  }

  @override
  Future<void> configure() async {
    if (_supported) {
      await (await _session).configure(
        const AudioSessionConfiguration.speech(),
      );
    }
  }

  @override
  Future<bool> setActive(bool active) async =>
      !_supported ||
      await (await _session).setActive(
        active,
        avAudioSessionSetActiveOptions: active
            ? AVAudioSessionSetActiveOptions.none
            : AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
}

/// 共享会话的独立使用凭据；释放旧凭据不能释放新播放或 Web 保活的持有。
final class AppAudioLease {
  AppAudioLease._(this._session, this.audible);
  final AppAudioSession _session;
  final bool audible;
  bool _released = false;
  Future<void> release() {
    if (_released) return Future.value();
    _released = true;
    return _session._release(this);
  }
}

/// 正文、试听、Web 保活共用的音频会话所有者，不持有播放器。— Codex + UI
final class AppAudioSession {
  AppAudioSession(this._backend);
  static final instance = AppAudioSession(PluginAudioSessionBackend());
  final AppAudioSessionBackend _backend;
  final _leases = <AppAudioLease>{};
  final _events = StreamController<AppAudioEvent>.broadcast(sync: true);
  final _busy = StreamController<bool>.broadcast(sync: true);
  StreamSubscription<AppAudioEvent>? _subscription;
  Future<void> _operations = Future.value();
  bool _interrupted = false, _temporary = false, _lastBusy = false;
  int _interruptionRevision = 0;

  Stream<AppAudioEvent> get events {
    _listen();
    return _events.stream;
  }

  /// 真实音频请求或外部中断期间，保活不得抢占/重新激活会话。
  bool get blocksKeepAlive =>
      _interrupted || _leases.any((lease) => lease.audible);
  Stream<bool> get keepAliveBlockedStream => _busy.stream;

  void _listen() {
    _subscription ??= _backend.events.listen(
      (event) {
        _temporary = event == AppAudioEvent.pause;
        _interrupted = _temporary || event == AppAudioEvent.loss;
        if (event != AppAudioEvent.resume) _interruptionRevision++;
        _publishBusy();
        _events.add(event);
      },
      onError: (Object error, StackTrace stack) {
        // 失去事件来源不能继续假定会话安全；不自动续播。
        _interrupted = true;
        _temporary = false;
        _interruptionRevision++;
        _publishBusy();
        _events.add(AppAudioEvent.stop);
        debugPrint('音频会话事件失败：$error');
      },
    );
  }

  void _publishBusy() {
    final busy = blocksKeepAlive;
    if (busy != _lastBusy) {
      _lastBusy = busy;
      _busy.add(busy);
    }
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<AppAudioLease?> acquire({bool audible = true}) {
    _listen();
    return _serial(() async {
      if (_temporary || (!audible && blocksKeepAlive)) return null;
      final revision = _interruptionRevision;
      // TTS/视频插件可能改写共享配置，每次新使用前重申应用的语音策略。
      await _backend.configure();
      if (revision != _interruptionRevision ||
          !await _backend.setActive(true)) {
        return null;
      }
      if (revision != _interruptionRevision) {
        if (_leases.isEmpty) await _backend.setActive(false);
        return null;
      }
      final lease = AppAudioLease._(this, audible);
      _leases.add(lease);
      _interrupted = false;
      _publishBusy();
      return lease;
    });
  }

  Future<void> _release(AppAudioLease lease) => _serial(() async {
    if (!_leases.remove(lease)) return;
    // 先处理共享激活态，再通知保活；其 acquire 会排在本次释放之后。
    try {
      if (_leases.isEmpty && !_interrupted) await _backend.setActive(false);
    } finally {
      _publishBusy();
    }
  });
}
