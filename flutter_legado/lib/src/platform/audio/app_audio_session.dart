import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// 语音中断与路由事件；恢复只是许可，是否续播由各播放会话判断。— Codex + UI
enum AppAudioEvent { pause, resume, interruptionEnded, stop, loss }

/// iOS 开始中断统一报告 unknown，是否允许恢复只在结束时给出；
/// Android unknown 则对应永久失焦，不能据后续 gain 自动续播。— Codex + UI
AppAudioEvent mapAudioInterruption(
  AudioInterruptionEvent event, {
  required bool isAndroid,
}) {
  if (!event.begin) {
    return event.type == AudioInterruptionType.unknown
        ? AppAudioEvent.interruptionEnded
        : AppAudioEvent.resume;
  }
  return isAndroid && event.type == AudioInterruptionType.unknown
      ? AppAudioEvent.loss
      : AppAudioEvent.pause;
}

/// 平台缝隙用于行为测试；Windows 继续使用现有播放器，不虚构系统焦点能力。
abstract interface class AppAudioSessionBackend {
  Stream<AppAudioEvent> get events;
  Future<void> configure({bool ignoreAudioFocus = false});
  Future<bool> setActive(bool active);
}

final class PluginAudioSessionBackend implements AppAudioSessionBackend {
  PluginAudioSessionBackend({
    Future<AudioSession> Function()? session,
    TargetPlatform? platform,
  }) : _readSession = session ?? (() => AudioSession.instance),
       _platform =
           platform ??
           (!kIsWeb && Platform.isAndroid
               ? TargetPlatform.android
               : !kIsWeb && Platform.isIOS
               ? TargetPlatform.iOS
               : null);

  final Future<AudioSession> Function() _readSession;
  final TargetPlatform? _platform;
  bool _ignoreAudioFocus = false, _hasAndroidFocus = false;
  Future<AudioSession> get _session => _readSession();
  bool get _isAndroid => _platform == TargetPlatform.android;
  bool get _supported => _isAndroid || _platform == TargetPlatform.iOS;

  @override
  Stream<AppAudioEvent> get events async* {
    if (!_supported) return;
    final session = await _session;
    final events = StreamController<AppAudioEvent>();
    final interruption = session.interruptionEventStream.listen((event) {
      // 连续语音不降音量掩盖正文；duck 与 pause 均暂停，unknown 不自动恢复。
      if (_isAndroid && _ignoreAudioFocus) return;
      events.add(mapAudioInterruption(event, isAndroid: _isAndroid));
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
  Future<void> configure({bool ignoreAudioFocus = false}) async {
    _ignoreAudioFocus = ignoreAudioFocus;
    if (_supported) {
      final session = await _session;
      // 先发布新策略，再放弃焦点，避免自己的放弃通知被当成新的失焦。
      if (_isAndroid && ignoreAudioFocus && _hasAndroidFocus) {
        if (!await session.setActive(false)) throw StateError('释放音频焦点失败');
        _hasAndroidFocus = false;
      }
      await session.configure(
        const AudioSessionConfiguration.speech().copyWith(
          avAudioSessionCategoryOptions: ignoreAudioFocus
              ? AVAudioSessionCategoryOptions.mixWithOthers
              : AVAudioSessionCategoryOptions.none,
        ),
      );
    }
  }

  @override
  Future<bool> setActive(bool active) async {
    if (!_supported) return true;
    if (_isAndroid && (_ignoreAudioFocus || (!active && !_hasAndroidFocus))) {
      return true;
    }
    final granted = await (await _session).setActive(
      active,
      avAudioSessionSetActiveOptions: active
          ? AVAudioSessionSetActiveOptions.none
          : AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
    );
    if (_isAndroid && granted) _hasAndroidFocus = active;
    return granted;
  }
}

/// 共享会话的独立使用凭据；释放旧凭据不能释放新播放或 Web 保活的持有。
final class AppAudioLease {
  AppAudioLease._(this._session, this.audible, this._isPlaying);
  final AppAudioSession _session;
  final bool audible;
  final bool Function()? _isPlaying;
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
  bool _ignoreAudioFocus = false;

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
        if (event == AppAudioEvent.resume ||
            event == AppAudioEvent.interruptionEnded) {
          // 显式恢复已消费旧中断；其迟到结束不能再控制新播放。
          if (!_temporary) return;
        } else {
          _interruptionRevision++;
        }
        _temporary = event == AppAudioEvent.pause;
        _interrupted = _temporary || event == AppAudioEvent.loss;
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

  /// 只调整平台策略，不触碰播放器。暂停持有者不因设置变更重新抢占焦点。
  Future<void> setIgnoreAudioFocus(bool value) => _serial(() async {
    if (_ignoreAudioFocus == value) return;
    _ignoreAudioFocus = value;
    if (!_leases.any((lease) => lease.audible)) return;
    final revision = _interruptionRevision;
    try {
      await _backend.configure(ignoreAudioFocus: value);
      if (_interrupted || revision != _interruptionRevision) return;
      final playing = _leases.any(
        (lease) => lease.audible && (lease._isPlaying?.call() ?? true),
      );
      if (playing && !await _backend.setActive(true)) {
        throw StateError('无法取得音频焦点，已暂停播放');
      }
    } catch (_) {
      // 平台拒绝或配置失败后不能继续报告正常播放；显式重播可再次申请。
      _interrupted = true;
      _temporary = false;
      _interruptionRevision++;
      _publishBusy();
      _events.add(AppAudioEvent.stop);
      rethrow;
    }
  });

  Future<AppAudioLease?> acquire({
    bool audible = true,
    bool userInitiated = false,
    bool Function()? isPlaying,
  }) {
    _listen();
    // 请求排队期间若又发生中断，旧请求也不能取得新会话。
    final revision = _interruptionRevision;
    return _serial(() async {
      final explicitPlayback = audible && userInitiated;
      if (revision != _interruptionRevision ||
          (_interrupted && !explicitPlayback) ||
          (!audible && blocksKeepAlive)) {
        debugPrint(
          '音频会话申请被应用阻止：手动=$explicitPlayback，中断=$_interrupted，过期=${revision != _interruptionRevision}',
        );
        return null;
      }
      // TTS/视频插件可能改写共享配置，每次新使用前重申应用的语音策略。
      try {
        await _backend.configure(
          ignoreAudioFocus: audible && _ignoreAudioFocus,
        );
        if (revision != _interruptionRevision) return null;
        if (!await _backend.setActive(true)) {
          debugPrint('音频会话申请被平台拒绝：手动=$explicitPlayback');
          return null;
        }
      } catch (error) {
        debugPrint('音频会话配置或激活异常：手动=$explicitPlayback，$error');
        rethrow;
      }
      if (revision != _interruptionRevision) {
        debugPrint('音频会话激活期间发生新中断，拒绝旧申请');
        if (_leases.isEmpty) await _backend.setActive(false);
        return null;
      }
      final lease = AppAudioLease._(this, audible, isPlaying);
      _leases.add(lease);
      _temporary = false;
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
