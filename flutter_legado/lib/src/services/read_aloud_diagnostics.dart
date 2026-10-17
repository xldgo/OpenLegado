import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// 用户主动开启的有界诊断，不参与播放决策。— Codex + UI
final class ReadAloudDiagnostics extends ChangeNotifier
    with WidgetsBindingObserver {
  ReadAloudDiagnostics({
    Future<Directory> Function()? directory,
    Future<Directory> Function()? exportDirectory,
    MethodChannel? channel,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _exportDirectory = exportDirectory ?? getTemporaryDirectory,
       _channel =
           channel ?? const MethodChannel('legado/read_aloud_diagnostics');

  static final instance = ReadAloudDiagnostics();
  static const maxFileBytes = 1024 * 1024;
  static const maxBufferedEvents = 256;
  final Future<Directory> Function() _directory;
  final Future<Directory> Function() _exportDirectory;
  final MethodChannel _channel;
  final _clock = Stopwatch()..start();
  final _pending = <String>[];
  final _counts = <String, int>{};
  Future<void> _writes = Future.value(), _controls = Future.value();
  File? _file;
  Timer? _timer, _deadline;
  bool _enabled = false, _writeBusy = false;
  Future<void>? _poll;
  int _session = 0, _sequence = 0, _bufferBytes = 0, _dropped = 0;
  int _pulses = 0, _frames = 0, _slowFrames = 0;
  int _maxBuildUs = 0, _maxRasterUs = 0;
  int _pendingStats = 0;
  String? lastError;
  bool get enabled => _enabled;
  int get session => _session;

  /// 与iOS原生使用相同的文件名摘要；只作关联，不保存正文/路径。
  static String fileKey(String path) {
    final uri = Uri.tryParse(path);
    final name = uri?.pathSegments.lastOrNull ?? '';
    return sha256.convert(utf8.encode(name)).toString().substring(0, 16);
  }

  Future<T> _control<T>(Future<T> Function() action) {
    final next = _controls.then((_) => action());
    _controls = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<void> start() => _control(() async {
    if (_enabled) return;
    await _writes;
    final dir = Directory(
      '${(await _directory()).path}/read_aloud_diagnostics',
    );
    await dir.create(recursive: true);
    final file = File('${dir.path}/events.jsonl');
    final previous = File('${file.path}.previous');
    // 新采集不继承旧会话；先完成清理再打开开关，失败时不混写。
    if (await previous.exists()) await previous.delete();
    await file.writeAsString('', mode: FileMode.write, flush: false);
    _file = file;
    _pending.clear();
    _bufferBytes = 0;
    _session = DateTime.now().microsecondsSinceEpoch;
    _sequence = _pulses = _dropped = 0;
    _frames = _slowFrames = _maxBuildUs = _maxRasterUs = 0;
    _counts.clear();
    lastError = null;
    _enabled = true;
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_timings);
    event('capture.start', {'platform': defaultTargetPlatform.name});
    await _nativeEnabled(true);
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_pulse()),
    );
    _deadline = Timer(const Duration(minutes: 30), () => unawaited(stop()));
    await _pulse(sample: true);
    notifyListeners();
  });

  Future<void> stop() => _control(() async {
    if (!_enabled) return;
    _timer?.cancel();
    _deadline?.cancel();
    await _poll;
    await _pulse(sample: true);
    await _nativeEnabled(false);
    await _pulse();
    event('capture.stop');
    _enabled = false;
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    await flush();
    await flush();
    notifyListeners();
  });

  Future<void> _nativeEnabled(bool value) async {
    if (defaultTargetPlatform != TargetPlatform.iOS || kIsWeb) return;
    try {
      await _channel
          .invokeMethod<void>('setEnabled', {'enabled': value})
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      if (_enabled) event('native.unavailable');
    }
  }

  /// 字段只允许计数、枚举和匿名标识；调用方不得传入正文或异常描述。
  void event(String name, [Map<String, Object?> fields = const {}]) {
    if (!_enabled) return;
    final line = jsonEncode({
      'session': _session,
      'seq': ++_sequence,
      'wallMs': DateTime.now().millisecondsSinceEpoch,
      'monoUs': _clock.elapsedMicroseconds,
      'event': name,
      ...fields,
    });
    final bytes = utf8.encode(line).length + 1;
    if (bytes > 65536) {
      _dropped++;
      return;
    }
    while (_pending.isNotEmpty &&
        (_pending.length >= maxBufferedEvents ||
            _bufferBytes + bytes > 65536)) {
      _bufferBytes -= utf8.encode(_pending.removeAt(0)).length;
      _dropped++;
    }
    _pending.add('$line\n');
    _bufferBytes += bytes;
  }

  void count(String name, [int amount = 1]) {
    if (_enabled) {
      _counts.update(name, (n) => n + amount, ifAbsent: () => amount);
    }
  }

  DiagnosticSpan? begin(String name, [Map<String, Object?> fields = const {}]) {
    if (!_enabled) return null;
    final operation = ++_sequence;
    event('$name.begin', {'operation': operation, ...fields});
    return DiagnosticSpan._(this, name, operation, _session);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    event('app.lifecycle', {'state': state.name});
    if (state == AppLifecycleState.paused) unawaited(flush());
  }

  void _timings(List<FrameTiming> timings) {
    if (!_enabled) return;
    for (final frame in timings) {
      _frames++;
      // 固定阈值只作比较口径，不等价于设备实际掉帧数量。
      if (frame.totalSpan.inMicroseconds > 16667) _slowFrames++;
      if (frame.buildDuration.inMicroseconds > _maxBuildUs) {
        _maxBuildUs = frame.buildDuration.inMicroseconds;
      }
      if (frame.rasterDuration.inMicroseconds > _maxRasterUs) {
        _maxRasterUs = frame.rasterDuration.inMicroseconds;
      }
    }
  }

  Future<void> _pulse({bool sample = false}) {
    if (!_enabled) return Future.value();
    return _poll ??= _collect(sample: sample).whenComplete(() => _poll = null);
  }

  Future<void> _collect({bool sample = false}) async {
    final capture = _session;
    sample = sample || ++_pulses % 3 == 0;
    if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
      try {
        final result = await _channel
            .invokeMapMethod<String, dynamic>('drain', {'sample': sample})
            .timeout(const Duration(seconds: 2));
        if (!_enabled || capture != _session) return;
        for (final raw in (result?['events'] as List? ?? const [])) {
          event('native.event', {'data': raw});
        }
        if (result?['sample'] != null) {
          event('native.resources', {'data': result!['sample']});
        }
        count('native.dropped', (result?['dropped'] as num?)?.toInt() ?? 0);
      } catch (_) {
        count('native.poll_failed');
      }
    }
    if (!_enabled || capture != _session) return;
    if (sample) {
      event('resources.summary', {
        'rssBytes': ProcessInfo.currentRss,
        'maxRssBytes': ProcessInfo.maxRss,
        'counts': Map<String, int>.of(_counts),
        'frames': _frames,
        'framesOver16ms': _slowFrames,
        'maxBuildUs': _maxBuildUs,
        'maxRasterUs': _maxRasterUs,
        'dropped': _dropped,
      });
      _counts.clear();
      _frames = _slowFrames = _maxBuildUs = _maxRasterUs = _dropped = 0;
    }
    await flush();
  }

  /// 异步批量写入、不fsync；最多两个1MiB文件，写失败不干扰播放。
  Future<void> flush() {
    final file = _file;
    if (file == null || _pending.isEmpty || _writeBusy) return _writes;
    _writeBusy = true;
    final data = _pending.join();
    _pending.clear();
    _bufferBytes = 0;
    final next = _writes.then((_) async {
      if (await file.exists() &&
          await file.length() + utf8.encode(data).length > maxFileBytes) {
        final previous = File('${file.path}.previous');
        if (await previous.exists()) await previous.delete();
        await file.rename(previous.path);
      }
      await file.writeAsString(data, mode: FileMode.append, flush: false);
    });
    _writes = next
        .catchError((Object _) {
          lastError = '诊断文件写入失败';
        })
        .whenComplete(() => _writeBusy = false);
    return _writes;
  }

  void mark() => event('user.heard_replay');

  /// 文件统计不阻塞音频返回；文件已回收时仅缺失大小，不改变合成结果。
  void recordCloudAudio(String path, {required bool fromCache}) {
    if (!_enabled) return;
    if (_pendingStats >= 8) {
      count('cloud.size_sample_skipped');
      return;
    }
    _pendingStats++;
    final capture = _session;
    unawaited(() async {
      int? bytes;
      try {
        bytes = await File(path).length();
      } catch (_) {
        /* 文件可能已回收。 */
      } finally {
        _pendingStats--;
      }
      if (!_enabled || capture != _session) return;
      event('cloud.audio', {
        'file': fileKey(path),
        'fromCache': fromCache,
        'bytes': bytes,
      });
      if (!fromCache && bytes != null) count('cloud.produced_bytes', bytes);
    }());
  }

  Future<File?> export() async {
    event('capture.export');
    await stop();
    return _control(() async {
      await flush();
      if (lastError != null) throw FileSystemException(lastError!);
      final root = Directory(
        '${(await _directory()).path}/read_aloud_diagnostics',
      );
      final current = File('${root.path}/events.jsonl');
      if (!await current.exists()) return null;
      final previous = File('${current.path}.previous');
      final output = File(
        '${(await _exportDirectory()).path}/read_aloud_diagnostics.jsonl',
      );
      final sink = output.openWrite();
      try {
        if (await previous.exists()) await sink.addStream(previous.openRead());
        await sink.addStream(current.openRead());
      } finally {
        await sink.close();
      }
      return output;
    });
  }
}

/// 旧采集会话的迟到结果不会混入新采集文件。
final class DiagnosticSpan {
  DiagnosticSpan._(this._owner, this._name, this._operation, this._session);
  final ReadAloudDiagnostics _owner;
  final String _name;
  final int _operation, _session;
  final _elapsed = Stopwatch()..start();
  bool _finished = false;
  int get elapsedMs => _elapsed.elapsedMilliseconds;
  void finish([Map<String, Object?> fields = const {}]) {
    if (_finished) return;
    _finished = true;
    if (_session != _owner.session) return;
    _owner.event('$_name.end', {
      'operation': _operation,
      'elapsedMs': elapsedMs,
      ...fields,
    });
  }
}
