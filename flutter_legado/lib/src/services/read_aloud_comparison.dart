import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'audio_playlist_player.dart';
import 'read_aloud_diagnostics.dart';
import 'stream_audio_player.dart';

enum ReadAloudComparisonMode { fixed, dynamic }

final class ComparisonAudio {
  const ComparisonAudio({
    required this.path,
    required this.sha256,
    required this.bytes,
  });
  final String path, sha256;
  final int bytes;
}

final class ComparisonFixture {
  ComparisonFixture({
    required this.label,
    required this.identity,
    required List<ComparisonAudio> audio,
  }) : audio = List.unmodifiable(audio);
  final String label, identity;
  final List<ComparisonAudio> audio;
}

/// 手动对照仅改变入队方式，不合成、不操作书籍设置。— Codex + UI
final class ReadAloudComparison extends ChangeNotifier {
  ReadAloudComparison({
    required this.player,
    required this.loadFixture,
    required this.saveReport,
    required this.closeSamples,
    required this.beforeRun,
    required this.afterRun,
    ReadAloudDiagnostics? diagnostics,
  }) : diagnostics = diagnostics ?? ReadAloudDiagnostics.instance;

  final StreamAudioPlayer player;
  final Future<ComparisonFixture> Function() loadFixture;
  final Future<File> Function(File, ReadAloudComparisonMode) saveReport;
  final Future<void> Function() closeSamples, beforeRun, afterRun;
  final ReadAloudDiagnostics diagnostics;
  AudioPlaylistPlayer get _native => player as AudioPlaylistPlayer;
  ComparisonFixture? fixture;
  ReadAloudComparisonMode? mode;
  final reports = <ReadAloudComparisonMode, File>{};
  String? error;
  String status = '尚未准备音频';
  bool preparing = false, starting = false, running = false;
  bool _closed = false,
      _loaded = false,
      _captureOwned = false,
      _sessionOwned = false;
  int _generation = 0, _next = 0, _run = 0;
  int currentIndex = -1;
  Duration position = Duration.zero, duration = Duration.zero;
  Future<void>? _prepareTask, _activation, _finishing;
  Object? _fillOwner;
  final _watch = Stopwatch();
  bool get busy => preparing || starting || running || _finishing != null;
  bool _valid(int generation) =>
      !_closed && generation == _generation && running;
  void _changed() {
    if (!_closed) notifyListeners();
  }

  void _event(String name, [Map<String, Object?> fields = const {}]) =>
      diagnostics.event('comparison.$name', {
        'mode': mode?.name,
        'run': _run,
        'fixture': fixture?.identity,
        'runElapsedMs': _watch.elapsedMilliseconds,
        ...fields,
      });

  Future<void> prepare() {
    if (_closed || busy) return _prepareTask ?? Future.value();
    return _prepareTask = _prepare().whenComplete(() => _prepareTask = null);
  }

  Future<void> _prepare() async {
    preparing = true;
    error = null;
    status = '正在复制缓存音频';
    _changed();
    try {
      final value = await loadFixture();
      if (_closed) return;
      if (value.audio.length < 6 || value.audio.length > 8) {
        throw StateError('对照需要6～8个有效音频，请重新准备');
      }
      fixture = value;
      reports.clear();
      currentIndex = -1;
      status = '已固定${value.audio.length}个音频，两组使用相同文件';
    } catch (failure) {
      fixture = null;
      error = failure is StateError ? '${failure.message}' : '准备缓存音频失败，请重试';
      status = '样本未准备完成';
    } finally {
      preparing = false;
      _changed();
    }
  }

  Future<void> start(ReadAloudComparisonMode selected) async {
    if (_closed || busy || fixture == null) return;
    final generation = ++_generation;
    mode = selected;
    reports.remove(selected);
    _run = DateTime.now().microsecondsSinceEpoch;
    currentIndex = -1;
    position = duration = Duration.zero;
    starting = running = true;
    _loaded = false;
    error = null;
    status = '正在停止正文并启动对照';
    _watch
      ..reset()
      ..start();
    _changed();
    try {
      _sessionOwned = true;
      await (_activation = beforeRun());
      if (!_valid(generation)) return;
      await diagnostics.stop();
      if (!_valid(generation)) return;
      _captureOwned = true;
      await diagnostics.start();
      if (!_valid(generation)) return;
      final files = fixture!.audio;
      _event('start', {
        'speed': 1,
        'preparation': 'plugin_default',
        'samples': [
          for (var i = 0; i < files.length; i++)
            {
              'index': i,
              'file': ReadAloudDiagnostics.fileKey(files[i].path),
              'sha256': files[i].sha256,
              'bytes': files[i].bytes,
            },
        ],
      });
      final count = selected == ReadAloudComparisonMode.fixed
          ? files.length
          : files.length.clamp(0, 3);
      _next = count;
      await _native.startPlaylist(
        AudioPlaylistItem(path: files.first.path, tag: 0),
        initialFollowing: [
          for (var i = 1; i < count; i++)
            AudioPlaylistItem(path: files[i].path, tag: i),
        ],
        speed: 1,
        onStarted: (tag) {
          if (!_valid(generation)) return;
          currentIndex = tag as int;
          position = duration = Duration.zero;
          _event('item_started', {'index': currentIndex, 'queued': _next});
          status = '正在播放第${currentIndex + 1}/${files.length}段';
          _changed();
          _fill(generation);
        },
        onCompleted: (tag) {
          if (!_valid(generation)) return;
          _event('item_completed', {'index': tag});
          if (tag == files.length - 1) unawaited(stop(reason: 'completed'));
        },
        onProgress: (p, d, _) {
          if (!_valid(generation)) return;
          position = p;
          duration = d;
          _changed();
        },
        onError: (failure) {
          if (!_valid(generation)) return;
          _event('error', {'type': failure.runtimeType.toString()});
          error = '音频播放失败，请导出本组日志';
          unawaited(stop(reason: 'error'));
        },
      );
      if (!_valid(generation)) return;
      starting = false;
      _loaded = true;
      _fill(generation);
      _changed();
    } catch (failure) {
      if (!_valid(generation)) return;
      _event('error', {'type': failure.runtimeType.toString()});
      error = '无法启动对照，请检查音频焦点和缓存文件';
      await stop(reason: 'error');
    }
  }

  void _fill(int generation) {
    if (!_valid(generation) ||
        !_loaded ||
        mode != ReadAloudComparisonMode.dynamic ||
        _fillOwner != null) {
      return;
    }
    final owner = Object();
    _fillOwner = owner;
    unawaited(() async {
      try {
        while (_valid(generation) &&
            _next < fixture!.audio.length &&
            _next - currentIndex - 1 < 2) {
          final index = _next;
          _event('append_begin', {'index': index, 'current': currentIndex});
          await _native.appendPlaylist([
            AudioPlaylistItem(path: fixture!.audio[index].path, tag: index),
          ]);
          if (!_valid(generation)) return;
          _next = index + 1;
          _event('append_end', {'index': index, 'current': currentIndex});
        }
      } catch (failure) {
        if (_valid(generation)) {
          _event('error', {'type': failure.runtimeType.toString()});
          error = '追加音频失败，请导出本组日志';
          unawaited(stop(reason: 'error'));
        }
      } finally {
        if (identical(_fillOwner, owner)) {
          _fillOwner = null;
          // 追加确认前可能已经再次换项，重新检查剩余项即可，不重播。
          if (_valid(generation) &&
              _next < fixture!.audio.length &&
              _next - currentIndex - 1 < 2) {
            _fill(generation);
          }
        }
      }
    }());
  }

  void mark() {
    if (!running || !diagnostics.enabled) return;
    _event('heard_replay', {
      'index': currentIndex,
      'positionMs': position.inMilliseconds,
    });
    diagnostics.mark();
  }

  Future<void> stop({String reason = 'manual'}) {
    if (_finishing != null) return _finishing!;
    if (!running && !starting && !_captureOwned && !_sessionOwned) {
      return Future.value();
    }
    ++_generation;
    running = starting = _loaded = false;
    _fillOwner = null;
    return _finishing = Future<void>.microtask(() => _finish(reason))
        .whenComplete(() {
          _finishing = null;
          _changed();
        });
  }

  Future<void> _finish(String reason) async {
    status = '正在停止并保存日志';
    _changed();
    _event('finish', {'reason': reason, 'index': currentIndex});
    try {
      try {
        await player.stop();
      } catch (_) {
        error ??= '停止播放失败，请退出后重试';
      }
      try {
        await _activation;
      } catch (_) {
        /* 焦点启动失败仍须归还可能取得的会话。 */
      }
      if (_sessionOwned) {
        _sessionOwned = false;
        try {
          await afterRun();
        } catch (_) {
          error ??= '释放音频会话失败，请退出后重试';
        }
      }
    } finally {
      if (_captureOwned) {
        _captureOwned = false;
        try {
          final report = await diagnostics.export();
          if (report != null && mode != null) {
            reports[mode!] = await saveReport(report, mode!);
          }
        } catch (_) {
          error ??= '保存本组日志失败，可在关于页重试导出';
        }
      }
      _watch.stop();
      status = reason == 'completed' ? '本组播放完成' : '本组已停止';
      if (reports.containsKey(mode)) status += '，日志已保存';
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await stop(reason: 'leave');
      await _prepareTask;
      // 播放器销毁成功后才删除副本，不能删除仍被原生使用的文件。
      await player.dispose();
      await closeSamples();
    } finally {
      super.dispose();
    }
  }
}
