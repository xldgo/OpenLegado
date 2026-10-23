import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart' as media;

import 'media_session_models.dart';
import '../platform/audio/app_audio_session.dart';
import '../platform/audio/read_aloud_audio_handler.dart';
import '../platform/audio/media_artwork_files.dart';

/// 音频焦点事件类型
enum AudioFocusEvent {
  /// 中断结束但未许可自动恢复；不能当作新的停止命令。
  interruptionEnded,

  /// 获得焦点
  gain,

  /// 永久丢失焦点
  loss,

  /// 暂时丢失焦点（需要暂停，之后会恢复）
  lossTransient,

  /// 短暂丢失焦点（可降低音量）
  lossTransientCanDuck,
}

/// 媒体按钮事件类型
enum MediaButtonEvent {
  /// 播放
  play,

  /// 暂停
  pause,

  /// 下一首
  skipToNext,

  /// 上一首
  skipToPrevious,

  /// 停止
  stop,
}

/// 系统媒体服务适配门面；播放事实归控制器，焦点归 AppAudioSession。— Codex + UI
class AudioService {
  AudioService._()
    : _session = AppAudioSession.instance,
      _initializeMedia = _nativeInit,
      _nativeMedia = true,
      _notificationClicks = media.AudioService.notificationClicked;

  @visibleForTesting
  AudioService.forTesting(
    this._session, {
    this._initializeMedia,
    this._notificationClicks = const Stream.empty(),
    MediaArtworkFiles? artworkFiles,
  }) : _nativeMedia = false,
       _artworkFiles = artworkFiles ?? MediaArtworkFiles();

  static final _instance = AudioService._();
  static AudioService get instance => _instance;
  final AppAudioSession _session;
  final bool _nativeMedia;
  final Future<ReadAloudAudioHandler> Function(ReadAloudAudioHandler)?
  _initializeMedia;
  final Stream<bool> _notificationClicks;
  MediaArtworkFiles _artworkFiles = MediaArtworkFiles();
  Future<ReadAloudAudioHandler>? _handlerFuture;
  ReadAloudAudioHandler? _handler;
  StreamSubscription<bool>? _clickSubscription;
  StreamSubscription<Object>? _mediaErrors;
  StreamSubscription<AppAudioEvent>? _focusSubscription;
  AppAudioLease? _focusLease;
  int _focusGeneration = 0, _lifecycle = 0, _artworkGeneration = 0;
  int _stateGeneration = 0;
  bool _initialized = false, _wakeEnabled = false, _playing = false;
  MediaPlaybackTarget? _pendingOpen;
  static const _wakeChannel = MethodChannel('legado/audio_wake_lock');
  final _audioFocusController = StreamController<AudioFocusEvent>.broadcast();
  final _mediaButtonController = StreamController<MediaButtonEvent>.broadcast();
  final _seekController = StreamController<MediaSeekRequest>.broadcast();
  final _openController = StreamController<MediaPlaybackTarget>.broadcast();

  static Future<ReadAloudAudioHandler> _nativeInit(
    ReadAloudAudioHandler handler,
  ) async {
    return media.AudioService.init(
      builder: () => handler,
      config: const media.AudioServiceConfig(
        androidNotificationChannelId: 'legado_playback_foreground',
        androidNotificationChannelName: '听书播放',
        androidNotificationIcon: 'drawable/ic_stat_read_aloud',
        androidStopForegroundOnPause: false,
        androidResumeOnClick: false,
        androidNotificationClickStartsActivity: true,
        artDownscaleWidth: 512,
        artDownscaleHeight: 512,
      ),
    );
  }

  bool get isInitialized => _initialized;
  Stream<AudioFocusEvent> get audioFocusStream {
    _focusSubscription ??= _session.events.listen((event) {
      _audioFocusController.add(switch (event) {
        AppAudioEvent.pause => AudioFocusEvent.lossTransient,
        AppAudioEvent.resume => AudioFocusEvent.gain,
        AppAudioEvent.interruptionEnded => AudioFocusEvent.interruptionEnded,
        AppAudioEvent.stop || AppAudioEvent.loss => AudioFocusEvent.loss,
      });
    });
    return _audioFocusController.stream;
  }

  Stream<MediaButtonEvent> get mediaButtonStream =>
      _mediaButtonController.stream;
  Stream<MediaSeekRequest> get seekStream => _seekController.stream;
  Stream<MediaPlaybackTarget> get openPlaybackStream => _openController.stream;
  Future<MediaPlaybackTarget?> takePendingOpen() async {
    final pending = _pendingOpen;
    _pendingOpen = null;
    return pending;
  }

  ReadAloudAudioHandler _createHandler() => ReadAloudAudioHandler(
    onPlay: () => _mediaButtonController.add(MediaButtonEvent.play),
    onPause: () => _mediaButtonController.add(MediaButtonEvent.pause),
    onStop: () => _mediaButtonController.add(MediaButtonEvent.stop),
    onNext: () => _mediaButtonController.add(MediaButtonEvent.skipToNext),
    onPrevious: () =>
        _mediaButtonController.add(MediaButtonEvent.skipToPrevious),
    onSeek: _seekController.add,
    onOpen: (target) {
      if (_openController.hasListener) {
        _openController.add(target);
      } else {
        _pendingOpen = target;
      }
    },
  );

  Future<void> init() async {
    if (_initialized) return;
    final factory = _initializeMedia;
    if (factory == null ||
        (_nativeMedia && (kIsWeb || !(Platform.isAndroid || Platform.isIOS)))) {
      return;
    }
    final lifecycle = _lifecycle;
    // audio_service 是进程级注册；释放后复用 Handler，不重复初始化插件。
    final handler = await (_handlerFuture ??= factory(_createHandler()));
    if (lifecycle != _lifecycle) return;
    _handler = handler;
    _initialized = true;
    if (_nativeMedia) {
      _mediaErrors ??= media.AudioService.asyncError.listen((error) {
        debugPrint('系统媒体展示失败：$error');
      });
    }
    _clickSubscription ??= _notificationClicks.listen((clicked) {
      if (clicked && _initialized) _handler?.openCurrent();
    });
  }

  Future<void> dispose() async {
    _lifecycle++;
    _artworkGeneration++;
    _stateGeneration++;
    _initialized = false;
    _handler?.clear();
    _handler = null;
    _pendingOpen = null;
    _playing = false;
    final errors = _mediaErrors, focus = _focusSubscription;
    // notificationClicked 是进程级回放流；保持唯一订阅，避免重新订阅重放旧点击。
    _mediaErrors = null;
    _focusSubscription = null;
    final releaseFocus = abandonAudioFocus();
    await _syncWakeLock();
    await releaseFocus;
    await errors?.cancel();
    await focus?.cancel();
  }

  /// 请求音频焦点
  ///
  /// 复刻原版 requestFocus()，在播放前调用。
  /// 返回 true 表示成功获取焦点。
  Future<bool> requestAudioFocus({bool userInitiated = false}) async {
    final generation = ++_focusGeneration;
    final lease = await _session.acquire(
      userInitiated: userInitiated,
      isPlaying: () => _playing,
    );
    if (generation != _focusGeneration) {
      await lease?.release();
      return false;
    }
    if (lease == null) return false;
    final previous = _focusLease;
    _focusLease = lease;
    await previous?.release();
    return true;
  }

  /// 放弃音频焦点
  ///
  /// 复刻原版 abandonFocus()，在停止播放或页面销毁时调用。
  Future<void> abandonAudioFocus() async {
    _focusGeneration++;
    final lease = _focusLease;
    _focusLease = null;
    await lease?.release();
  }

  Future<void> updateProgress(MediaPlaybackProgress progress) async {
    if (_initialized) _handler?.publishProgress(progress);
  }

  Future<void> updateMetadata({
    required String title,
    String artist = '',
    String album = '',
    String mediaId = '',
    int sessionToken = 0,
    String timerText = '',
  }) async {
    if (!_initialized) return;
    _stateGeneration++;
    _handler?.publishMetadata(
      title: title,
      artist: artist,
      album: album,
      mediaId: mediaId,
      sessionToken: sessionToken,
      timerText: timerText,
    );
  }

  Future<void> updateArtwork({
    required String mediaId,
    required int sessionToken,
    required Uint8List? artworkBytes,
  }) async {
    final handler = _handler;
    if (!_initialized ||
        handler == null ||
        !handler.owns(mediaId, sessionToken)) {
      return;
    }
    final generation = ++_artworkGeneration;
    final uri = artworkBytes == null
        ? null
        : await _artworkFiles.write(artworkBytes);
    if (_initialized &&
        identical(handler, _handler) &&
        generation == _artworkGeneration) {
      handler.publishArtwork(mediaId, sessionToken, uri);
    }
    await _artworkFiles.prune(keep: _handler?.mediaItem.value?.artUri);
  }

  Future<void> setPlaying(bool playing) async {
    _playing = playing;
    await _syncWakeLock();
  }

  Future<void> setWakeLock(bool enabled) async {
    _wakeEnabled = enabled;
    await _syncWakeLock();
  }

  Future<void> _syncWakeLock() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _wakeChannel.invokeMethod<void>('update', {
        'enabled': _wakeEnabled,
        'playing': _playing,
      });
    } on MissingPluginException {
      // 不支持的平台不宣称持有额外的 Android 唤醒锁。
    } on PlatformException catch (error) {
      debugPrint('更新听书唤醒锁失败：$error');
    }
  }

  Future<void> updatePlaybackState({
    required String state,
    int position = 0,
  }) async {
    if (_initialized) _handler?.publishState(state);
  }

  Future<void> notifyPlaying({int position = 0}) async {
    await _notify('playing', true);
  }

  Future<void> notifyPaused({int position = 0}) async {
    await _notify('paused', false);
  }

  Future<void> notifyStopped() async {
    _artworkGeneration++;
    _pendingOpen = null;
    await _notify('stopped', false);
  }

  Future<void> _notify(String state, bool playing) async {
    final generation = ++_stateGeneration;
    await setPlaying(playing);
    if (generation == _stateGeneration) await updatePlaybackState(state: state);
  }
}
