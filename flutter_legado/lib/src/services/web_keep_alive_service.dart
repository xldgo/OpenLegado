import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform/audio/app_audio_session.dart';

enum WebKeepAliveStatus {
  notApplicable,
  idle,
  active,

  /// 真实音频持有或外部中断期间暂缓，不抢占音频会话。
  deferredByRealAudio,
  failed,
}

/// iOS Web 保活仅管理近静音音轨；共享会话使用独立凭据。— Codex + UI
class WebKeepAliveService {
  WebKeepAliveService({
    AppAudioSession? audioSession,
    bool Function()? isIOS,
    Future<bool?> Function(bool)? setEnabled,
  }) : _session = audioSession ?? AppAudioSession.instance,
       _isIOS = isIOS ?? (() => Platform.isIOS),
       _setEnabled = setEnabled ?? _invokePlatform;

  static final instance = WebKeepAliveService();
  static const channel = MethodChannel('legado/web_keepalive');
  static Future<bool?> _invokePlatform(bool enabled) =>
      channel.invokeMethod<bool>('setEnabled', {'enabled': enabled});

  final AppAudioSession _session;
  final bool Function() _isIOS;
  final Future<bool?> Function(bool) _setEnabled;
  bool _serviceRunning = false, _keepAliveActive = false;
  AppAudioLease? _lease;
  StreamSubscription<bool>? _subscription;
  Future<void> _operations = Future.value();
  WebKeepAliveStatus _status = WebKeepAliveStatus.idle;

  WebKeepAliveStatus get status => _status;
  bool get isSupported => _isIOS();
  bool get isRunning => _serviceRunning;
  bool get isActive => _keepAliveActive;

  Future<WebKeepAliveStatus> start() {
    _serviceRunning = true;
    if (!isSupported) {
      _status = WebKeepAliveStatus.notApplicable;
      return Future.value(_status);
    }
    _subscription ??= _session.keepAliveBlockedStream.listen((_) {
      unawaited(_schedule());
    });
    return _schedule();
  }

  Future<WebKeepAliveStatus> stop() {
    _serviceRunning = false;
    return _schedule();
  }

  Future<WebKeepAliveStatus> _schedule() {
    final next = _operations.then((_) => _reconcile());
    _operations = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        debugPrint('Web 保活协调失败：$error');
      },
    );
    return next;
  }

  Future<void> _stopTrack() async {
    final lease = _lease;
    _lease = null;
    try {
      if (_keepAliveActive) await _setEnabled(false);
    } finally {
      _keepAliveActive = false;
      await lease?.release();
    }
  }

  Future<WebKeepAliveStatus> _reconcile() async {
    try {
      if (!isSupported) return _status = WebKeepAliveStatus.notApplicable;
      if (!_serviceRunning || _session.blocksKeepAlive) {
        await _stopTrack();
        if (!_serviceRunning) {
          await _subscription?.cancel();
          _subscription = null;
        }
        return _status = _serviceRunning
            ? WebKeepAliveStatus.deferredByRealAudio
            : WebKeepAliveStatus.idle;
      }
      if (_keepAliveActive) return _status = WebKeepAliveStatus.active;
      final lease = await _session.acquire(audible: false);
      if (lease == null) {
        return _status = WebKeepAliveStatus.deferredByRealAudio;
      }
      _lease = lease;
      if (!_serviceRunning || _session.blocksKeepAlive) {
        await _stopTrack();
        return _status = _serviceRunning
            ? WebKeepAliveStatus.deferredByRealAudio
            : WebKeepAliveStatus.idle;
      }
      _keepAliveActive = await _setEnabled(true) == true;
      if (!_keepAliveActive) {
        await _stopTrack();
        return _status = WebKeepAliveStatus.failed;
      }
      // 启动音轨期间可能已被停止或有正文/试听申请，按最新意图收口。
      if (!_serviceRunning || _session.blocksKeepAlive) {
        await _stopTrack();
        return _status = _serviceRunning
            ? WebKeepAliveStatus.deferredByRealAudio
            : WebKeepAliveStatus.idle;
      }
      return _status = WebKeepAliveStatus.active;
    } catch (error) {
      try {
        await _stopTrack();
      } catch (cleanup) {
        debugPrint('Web 保活释放失败：$cleanup');
      }
      debugPrint('Web 保活不可用，仅前台可用：$error');
      return _status = _serviceRunning
          ? WebKeepAliveStatus.failed
          : WebKeepAliveStatus.idle;
    }
  }
}
