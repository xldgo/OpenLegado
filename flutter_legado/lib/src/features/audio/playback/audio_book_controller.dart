import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/contracts/audio_book_service.dart';
import '../../../domain/contracts/audio_playback_settings_repository.dart';
import '../../../providers/audio/audio_state.dart';
import '../../../services/stream_audio_player.dart';
import '../../../utils/audio_skip_policy.dart';
import 'audio_book_host.dart';

/// 流媒体进度写库的位置增量阈值（毫秒）
///
/// 播放中高频 onProgress 回调下仅做内存比较，累计播放位置增量达到该阈值
/// 才真正写库（避免高频 IO）；生命周期节点（完成/切章/暂停/停止/退出）
/// 不受该阈值限制。[A3 | 2026-10-03]
const int kStreamProgressSaveDeltaMs = 5000;

/// 恢复进度「接近章尾」容差（毫秒）
///
/// [P1 竞态修复 | 2026-10-03] 存量进度 ≥ duration - 该值 时视为「本章已播完」，
/// 恢复时不再 seek（否则 seek 到章尾会立即触发完成回调 → 秒完切章级联）。
/// 依据：原版无对应恢复判定——完成的章不落可恢复位置：AudioPlay.next() 在
/// completeCurrentChapter 之后立即把 durChapterPos 清零；末章播完由
/// isPlayToEnd() 走 playNew() 从头播（AudioPlay.kt:615-621、752-778）。
/// 故按最小防护取「从头播」。取 1s：覆盖本应用完成判定
/// （stream_audio_player.dart：position ≥ duration-200ms 且停止）写入的完成值，
/// 并给真机时长/位置上报粒度留余量；不取 95% 比例阈值，避免长章节尾部真实
/// 续听位置（如 3 小时章的最后 2 分钟）被误判为播完。
const int kStreamRestoreNearEndToleranceMs = 1000;

/// 流媒体章节归属标识
///
/// [AudioBookController.play] 发起 `playUrl` 时绑定，[StreamAudioPlayer] 在进度/
/// 完成回调中原样回传；回调先与当前 state.bookUrl/currentIndex 比对，归属
/// 不一致（切章后迟到的旧章事件）整条丢弃——旧章最终位置不得写进新章进度键，
/// 这是 P1 级联跳章的根因修复。[P1 竞态修复 | 2026-10-03]
typedef StreamChapterTag = ({String bookUrl, int chapterIndex});

/// 音频书播放编排及进度保存，复用宿主状态与共享播放器。— Codex + UI
final class AudioBookController {
  AudioBookController({
    required this._host,
    required this._service,
    required this._settings,
    required this._player,
    int Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AudioBookHost _host;
  final AudioBookService _service;
  final AudioPlaybackSettingsRepository _settings;
  final StreamAudioPlayer _player;
  final int Function() _clock;
  AudioState get _state => _host.readState();
  set _state(AudioState value) => _host.writeState(value);
  int get _playToken => _host.currentToken();
  bool get _disposed => _released || _host.isDisposed();
  bool _released = false;
  bool _introSkipEvaluated = false;
  AudioSkipWindow? _skipWindow;
  int _lastProgressEmitMs = 0;
  String _lastProgressSaveKey = '';
  int _lastProgressSavedPosMs = 0;
  static const int _kProgressThrottleMs = 400;

  bool _stale(int token) => _disposed || token != _playToken;

  void handleCompleted(Object? tag) {
    if (ownsChapter(tag)) unawaited(_onStreamCompleted());
  }

  void handleError(Object error, Object? tag) {
    if (!ownsChapter(tag) || !_state.isStreamMode) return;
    _host.pause();
    _state = _state.copyWith(
      state: PlayerState.error,
      errorMessage: '音频播放失败：$error',
    );
  }

  /// 宿主负责同步发布暂停态及媒体通知，保存仍使用暂停时的同一书章。
  void pause() {
    if (_disposed) return;
    unawaited(_player.pause());
    unawaited(persistPosition(force: true));
  }

  Future<bool> resume() async {
    if (_disposed ||
        !_state.isStreamMode ||
        _state.state != PlayerState.paused ||
        !_player.isInitialized) {
      return false;
    }
    final token = _playToken;
    await _player.resume();
    if (_stale(token)) return true;
    _state = _state.copyWith(state: PlayerState.playing);
    await _host.activateMedia();
    return true;
  }

  Future<void> play() async {
    if (_disposed || !_state.isStreamMode || _state.chapters.isEmpty) return;
    _state = _state.copyWith(state: PlayerState.loading, errorMessage: null);
    final token = _host.advanceToken();
    try {
      await _host.stopSystemTts();
      if (token != _playToken || _disposed) return;
      var index = _state.currentIndex;
      while (index < _state.chapters.length) {
        final media = await _service.getAudioChapterMedia(
          _state.bookUrl,
          index,
        );
        if (token != _playToken || _disposed) return;
        final isVolume = media.isVolume;
        final mediaUrl = media.mediaUrl.trim();
        if (isVolume || mediaUrl.isEmpty) {
          if (index + 1 >= _state.chapters.length) {
            _state = _state.copyWith(
              errorMessage: (!isVolume && mediaUrl.isEmpty)
                  ? '未获取到资源链接'
                  : '无可播放章节',
              state: PlayerState.error,
            );
            return;
          }
          index++;
          _state = _state.copyWith(currentIndex: index);
          continue;
        }
        final lyric = media.lyric?.trim();
        _state = _state.copyWith(
          currentIndex: index,
          mediaUrl: mediaUrl,
          positionMs: 0,
          durationMs: 0,
          lyric: (lyric == null || lyric.isEmpty) ? null : lyric,
          state: PlayerState.playing,
        );
        // [P1] 绑定本章归属：播放器在进度/完成回调中原样回传，切章后旧播放器
        // 迟到的回调据此被丢弃，不会写进新章进度键
        await _player.playUrl(
          mediaUrl,
          speed: _state.config.speed,
          tag: (bookUrl: _state.bookUrl, chapterIndex: index),
        );
        if (token != _playToken || _disposed) return;
        await _host.activateMedia();
        if (_stale(token)) return;
        _introSkipEvaluated = false;
        _skipWindow = null;
        // 恢复进度；从头播放时再套用片头跳过
        var restoredPos = 0;
        try {
          final progress = await _service.getAudioProgress(
            _state.bookUrl,
            index,
          );
          if (_stale(token)) return;
          restoredPos = progress;
          if (restoredPos > 1500 && token == _playToken && !_disposed) {
            if (_isNearChapterEnd(restoredPos)) {
              // [P1 辅修] 历史污染值/完成值按「本章已播完」处理：不 seek，
              // 从头播（依据见 kStreamRestoreNearEndToleranceMs 注释）
              restoredPos = 0;
            } else {
              await _player.seek(Duration(milliseconds: restoredPos));
            }
          }
        } catch (e) {
          debugPrint('恢复音频进度失败: $e');
        }
        if (_stale(token)) return;
        if (restoredPos <= 1500) {
          await _applyIntroSkipIfNeeded(token);
        }
        return;
      }
    } catch (e) {
      if (token != _playToken || _disposed) return;
      _state = _state.copyWith(
        errorMessage: e.toString(),
        state: PlayerState.error,
      );
    }
  }

  /// 回调归属校验：tag 是否为当前播放章节（bookUrl + chapterIndex 双匹配）
  ///
  /// 仅流媒体路径的进度/完成回调需要校验（TTS 本地播放不传 tag，恒不匹配）。
  bool ownsChapter(Object? tag) {
    if (_disposed || tag is! StreamChapterTag) return false;
    return tag.bookUrl == _state.bookUrl &&
        tag.chapterIndex == _state.currentIndex;
  }

  /// 存量进度是否已到本章末尾（视为已播完）
  ///
  /// 时长未知（未初始化）时不做判定，保持既有恢复行为。
  bool _isNearChapterEnd(int positionMs) {
    final durationMs = _player.duration.inMilliseconds;
    if (durationMs <= 0) return false;
    return positionMs >= durationMs - kStreamRestoreNearEndToleranceMs;
  }

  Future<void> _onStreamCompleted() async {
    if (_disposed ||
        !_state.isStreamMode ||
        _state.state != PlayerState.playing) {
      return;
    }
    final token = _playToken;
    // [A4] 章自然播完：按章停止计数（单曲循环每次完成同样计数，
    // 对齐原版 STATE_ENDED → completeCurrentChapter → onChapterCompleted）
    if (_host.consumeChapterStop()) {
      _host.stop(); // stop 内 force 写当前章进度（A3）
      return;
    }
    if (_state.mode == AudioPlayMode.singleLoop) {
      // [A3] 单曲循环从章首重播：显式清零进度，避免周期写入导致「循环回到结尾」
      await _resetStreamProgress();
      if (_stale(token)) return;
      await _host.replay();
      return;
    }
    // [A3] 播完（含片尾跳过）/ 自动切章前写当前章进度
    await persistPosition(force: true);
    if (_stale(token)) return;
    if (_state.hasNext) {
      await _host.nextChapter();
      return;
    }
    _host.stop();
  }

  Future<void> _applyIntroSkipIfNeeded(int token) async {
    if (_introSkipEvaluated || token != _playToken || _disposed) return;
    final dur = _player.duration.inMilliseconds;
    if (dur <= 0) return;
    final window = await _resolveSkipWindow(dur);
    if (_stale(token)) return;
    _skipWindow = window;
    _introSkipEvaluated = true;
    if (window == null) return;
    final seekTo = introSeekPosition(currentPositionMs: 0, window: window);
    if (seekTo == null) return;
    await _player.seek(Duration(milliseconds: seekTo));
    if (_stale(token)) return;
    _state = _state.copyWith(positionMs: seekTo, durationMs: dur);
  }

  Future<void> _maybeApplySkip(int positionMs, int durationMs) async {
    if (_disposed ||
        !_state.isStreamMode ||
        _state.state != PlayerState.playing) {
      return;
    }
    final token = _playToken;
    if (!_introSkipEvaluated && positionMs <= 0) {
      await _applyIntroSkipIfNeeded(token);
    }
    if (_stale(token)) return;
    final window = _skipWindow ?? await _resolveSkipWindow(durationMs);
    if (_stale(token)) return;
    _skipWindow = window;
    if (window == null) return;
    if (shouldSkipOutro(currentPositionMs: positionMs, window: window)) {
      await _onStreamCompleted();
    }
  }

  Future<AudioSkipWindow?> _resolveSkipWindow(int durationMs) async {
    var globalOpen = 0;
    var globalClose = 0;
    try {
      final settings = await _settings.load();
      globalOpen = settings.openCredits;
      globalClose = settings.closeCredits;
    } catch (_) {}
    if (_disposed) return null;
    final cfg = _host.boundBook()?.readConfig;
    final cfgMap = cfg == null
        ? null
        : <String, dynamic>{
            'openCredits': cfg.openCredits,
            'closeCredits': cfg.closeCredits,
            // freezed 暂无该字段：有书级非零片头/片尾则视为书级
            'useGlobalAudioSkip': cfg.openCredits == 0 && cfg.closeCredits == 0,
          };
    final open = resolveOpenCredits(readConfig: cfgMap, globalOpen: globalOpen);
    final close = resolveCloseCredits(
      readConfig: cfgMap,
      globalClose: globalClose,
    );
    return resolveAudioSkipWindow(
      durationMs: durationMs,
      introSeconds: open,
      outroSeconds: close,
    );
  }

  /// 流媒体进度写库（A3）
  ///
  /// 节流：同一 bookUrl+chapterIndex 下，非 [force] 调用仅当播放位置增量
  /// ≥ [kStreamProgressSaveDeltaMs] 时写库（onProgress 高频回调下只做内存
  /// 比较）；[force] 用于生命周期节点（暂停/停止/完成/切章/退出）。
  /// 位置优先取播放器实际位置，未初始化时回退 _state.positionMs。
  ///
  /// 写入归属恒为调用时刻的 _state.currentIndex；播放器回调路径（onProgress）
  /// 必须先在回调入口经 [ownsChapter] 校验归属，切章后迟到的旧章
  /// 回调不得进入本方法。[P1 竞态修复]
  Future<void> persistPosition({int? positionMs, bool force = false}) async {
    if (_disposed || !_state.isStreamMode) return; // TTS 无毫秒时间轴，不写该键（避免污染流媒体恢复）
    final bookUrl = _state.bookUrl;
    if (bookUrl.isEmpty) return;
    final chapterIndex = _state.currentIndex;
    final key = '$bookUrl:$chapterIndex';
    // 播放器位置只在同一章内可信（切章后 Fake/真机可能仍持有上一章位置）
    final playerPos = _player.position.inMilliseconds;
    final position =
        positionMs ??
        ((key == _lastProgressSaveKey && playerPos > 0)
            ? playerPos
            : _state.positionMs);
    if (position <= 0) return; // 起始 0 位置不写，避免覆盖已存进度
    if (key == _lastProgressSaveKey) {
      final delta = (position - _lastProgressSavedPosMs).abs();
      if (position == _lastProgressSavedPosMs) return; // 同值去重
      if (!force && delta < kStreamProgressSaveDeltaMs) return;
    }
    _lastProgressSaveKey = key;
    _lastProgressSavedPosMs = position;
    try {
      await _service.saveAudioProgress(bookUrl, chapterIndex, position);
    } catch (e) {
      debugPrint('保存音频进度失败: $e');
    }
  }

  /// 单曲循环重播前清零当前章进度
  Future<void> _resetStreamProgress() async {
    final bookUrl = _state.bookUrl;
    if (bookUrl.isEmpty) return;
    final chapterIndex = _state.currentIndex;
    try {
      await _service.saveAudioProgress(bookUrl, chapterIndex, 0);
      _lastProgressSaveKey = '$bookUrl:$chapterIndex';
      _lastProgressSavedPosMs = 0;
    } catch (e) {
      debugPrint('重置音频进度失败: $e');
    }
  }

  /// 容器销毁时尽力写一次进度（onDispose 内调用，任何异常不得影响销毁）
  void _saveOnDispose(AudioState? snapshot) {
    try {
      final s = snapshot;
      if (s == null || !s.isStreamMode || s.bookUrl.isEmpty) return;
      final key = '${s.bookUrl}:${s.currentIndex}';
      final playerPos = _player.position.inMilliseconds;
      final position = (key == _lastProgressSaveKey && playerPos > 0)
          ? playerPos
          : s.positionMs;
      if (position <= 0) return;
      if (key == _lastProgressSaveKey && position == _lastProgressSavedPosMs) {
        return;
      }
      unawaited(
        _service
            .saveAudioProgress(s.bookUrl, s.currentIndex, position)
            .catchError((Object e) {
              debugPrint('退出时保存音频进度失败: $e');
            }),
      );
    } catch (e) {
      debugPrint('退出时保存音频进度失败: $e');
    }
  }

  void handleProgress(Duration position, Duration duration, Object? tag) {
    if (_disposed || !_state.isStreamMode) return;
    final pos = position, dur = duration;
    // [P1] 回调必须归属当前章：切章瞬间旧播放器 stop 前送达的最终回调
    // （position≈旧章时长）若按 _state.currentIndex 归属会写进新章进度键，
    // 恢复逻辑随即 seek 到新章章尾 → 秒完 → 再切章，形成自持级联；
    // 归属不一致则整条丢弃（不写库、不刷新 UI）。
    if (!ownsChapter(tag)) return;
    // [A3] 播放中周期写进度：显式传入回调位置，位置增量 <5s 时仅内存比较不写库
    unawaited(persistPosition(positionMs: pos.inMilliseconds));
    final now = _clock();
    if (now - _lastProgressEmitMs < _kProgressThrottleMs &&
        dur.inMilliseconds == _state.durationMs) {
      // 片尾仍需检测
      unawaited(_maybeApplySkip(pos.inMilliseconds, dur.inMilliseconds));
      return;
    }
    _lastProgressEmitMs = now;
    _state = _state.copyWith(
      positionMs: pos.inMilliseconds,
      durationMs: dur.inMilliseconds,
    );
    unawaited(_maybeApplySkip(pos.inMilliseconds, dur.inMilliseconds));
  }

  /// 仅保存宿主的最终快照；共享播放器由既有宿主清理路径释放。
  void dispose({AudioState? snapshot}) {
    if (_released) return;
    _released = true;
    _saveOnDispose(snapshot);
  }
}
