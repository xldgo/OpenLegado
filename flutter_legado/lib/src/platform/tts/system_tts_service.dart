import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'system_tts.dart';

/// 系统朗读的唯一插件实例；共享会话由 AppAudioSession 持有。— Codex + UI
class SystemTtsService implements SystemTts {
  SystemTtsService({
    this._tts,
    this.excludedVoiceKeys,
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform;

  static const _engineKey = 'system_tts_engine';
  static const _voiceKey = 'system_tts_voice';
  final TargetPlatform _platform;
  final Future<Set<String>> Function(String engine)? excludedVoiceKeys;
  FlutterTts? _tts;
  FlutterTts get _plugin => _tts ??= FlutterTts();
  Future<void>? _initialization;
  Future<void> _operations = Future.value();
  Completer<SystemTtsOutcome>? _native;
  _Speech? _active;
  _Speech? _paused;
  int _generation = 0;

  /// 回调坐标相对整次 speak 的原文，已包含分片与 Android 恢复偏移。
  @override
  void Function(int start, int end)? onProgress;
  int _maxLength = 4000;
  double _normalRate = 0.5;
  double _maxRate = 1.0;
  List<SystemTtsVoice> _voices = [];
  String _engine = '';
  String _voice = '';

  @override
  bool get isSupported =>
      !kIsWeb &&
      (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS);
  @override
  bool get supportsEngineSelection => _platform == TargetPlatform.android;
  @override
  bool get isPaused => _paused != null;
  @override
  String get selectedEngine => _engine;
  @override
  String get selectedVoice => _voice;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  @override
  Future<void> initialize() => _initialization ??= _initialize().catchError((
    Object error,
    StackTrace stack,
  ) {
    _initialization = null;
    Error.throwWithStackTrace(error, stack);
  });

  Future<void> _initialize() async {
    if (!isSupported) throw StateError('此平台暂不支持系统朗读');
    final prefs = await SharedPreferences.getInstance();
    _engine = prefs.getString(_engineKey) ?? '';
    _voice = prefs.getString(_voiceKey) ?? '';
    if (supportsEngineSelection) {
      final engines = await getEngines();
      final defaultEngine = (await _plugin.getDefaultEngine)?.toString() ?? '';
      final engine = _engine.isEmpty ? defaultEngine : _engine;
      if (engine.isEmpty || !engines.contains(engine)) {
        throw StateError('系统朗读引擎不可用，请在系统设置安装或选择 TTS 引擎');
      }
      _accept(await _plugin.setEngine(engine), '选择系统引擎失败');
      await _plugin.setQueueMode(0);
      _maxLength = await _plugin.getMaxSpeechInputLength ?? 4000;
    } else {
      await _plugin.autoStopSharedSession(false);
    }
    // 4.2.5 的 iOS stop 不结束等待完成的 Future，使用事件与终止屏障。
    await _plugin.awaitSpeakCompletion(false);
    _plugin.setProgressHandler(_nativeProgress);
    _plugin.setCompletionHandler(
      () => _nativeFinished(SystemTtsOutcome.completed),
    );
    _plugin.setCancelHandler(() => _nativeFinished(SystemTtsOutcome.cancelled));
    _plugin.setPauseHandler(() {
      if (supportsEngineSelection) _nativeFinished(SystemTtsOutcome.paused);
    });
    final range = await _plugin.getSpeechRateValidRange;
    _normalRate = range.normal;
    _maxRate = range.max;
    // 插件错误事件没有朗读 ID；错误只终止当前声音，不用于推进段落。
    _plugin.setErrorHandler((message) {
      _nativeFinished(SystemTtsOutcome.cancelled);
      final active = _active;
      if (active != null) {
        _finishError(active, StateError('系统朗读失败：$message'), StackTrace.current);
        unawaited(
          stop().catchError((Object error) {
            debugPrint('系统朗读停止失败：$error');
          }),
        );
      }
    });
  }

  /// 目录发现独立于当前选择；已失效的音色不能阻止用户打开目录重新选择。
  Future<void> _loadVoices() async {
    final rawVoices = await _plugin.getVoices;
    _voices =
        [
              for (final value in (rawVoices as List? ?? []))
                if (value is Map &&
                    !(value['features'] is List &&
                        (value['features'] as List).contains('notInstalled')))
                  SystemTtsVoice.fromMap(value),
            ]
            .where((voice) => voice.name.isNotEmpty && voice.locale.isNotEmpty)
            .toList();
  }

  Future<void> _selectVoice([String? voiceOverride]) async {
    final selectedVoice = voiceOverride ?? _voice;
    await _loadVoices();
    final excluded = await excludedVoiceKeys?.call(_engine) ?? <String>{};
    if (selectedVoice.isNotEmpty && excluded.contains(selectedVoice)) {
      throw StateError('所选系统音色已禁用或排除，请重新选择音色');
    }
    final allowed = _voices.where((v) => !excluded.contains(v.key)).toList();
    final chinese = allowed
        .where(
          (v) => v.locale.toLowerCase().replaceAll('_', '-').startsWith('zh'),
        )
        .toList();
    chinese.sort((a, b) {
      final offline = (a.networkRequired ? 1 : 0).compareTo(
        b.networkRequired ? 1 : 0,
      );
      if (offline != 0) return offline;
      int rank(SystemTtsVoice v) =>
          v.locale.replaceAll('_', '-').toLowerCase() == 'zh-cn' ? 0 : 1;
      return rank(a).compareTo(rank(b));
    });
    SystemTtsVoice? chosen;
    for (final voice in allowed) {
      if (voice.key == selectedVoice) chosen = voice;
    }
    if (selectedVoice.isNotEmpty && chosen == null) {
      throw StateError('所选系统音色已不可用，请重新选择音色');
    }
    chosen ??= chinese.isEmpty ? null : chinese.first;
    if (chosen != null) {
      _accept(await _plugin.setVoice(chosen.toMap()), '中文语音不可用');
    } else {
      if (excluded.isNotEmpty) throw StateError('没有可用的中文系统音色，请恢复或安装中文语音');
      if (await _plugin.isLanguageAvailable('zh-CN') != true) {
        throw StateError('未找到中文系统语音，请在系统设置安装中文语音');
      }
      _accept(await _plugin.setLanguage('zh-CN'), '中文语音不可用');
    }
  }

  static void _accept(dynamic result, String message) {
    if (result == 0 || result == false) throw StateError(message);
  }

  @override
  Future<List<String>> getEngines() async {
    if (!supportsEngineSelection) return [];
    return ((await _plugin.getEngines) as List? ?? [])
        .map((v) => v.toString())
        .toList();
  }

  @override
  Future<List<SystemTtsVoice>> getVoices() async {
    await initialize();
    await _serialize(_loadVoices);
    return List.unmodifiable(_voices);
  }

  @override
  Future<void> saveSettings({
    required String engine,
    required String voice,
  }) async {
    await stop();
    final prefs = await SharedPreferences.getInstance();
    // 明确选择音色时随引擎一起保存；单独切引擎由设置界面传空音色。
    await prefs.setString(_voiceKey, voice);
    await prefs.setString(_engineKey, engine);
    _initialization = null;
    await initialize();
  }

  /// 倍速映射到各平台有效 rate，保持 1 倍对应系统常速。
  static double speechRate(double speed, double normal, double maximum) {
    final value = speed.clamp(0.5, 3.0);
    return value <= 1
        ? normal * value
        : normal + (maximum - normal) * (value - 1) / 2;
  }

  /// 按 UTF-16 长度分片，优先句末，不切断代理对；原段落归属保持不变。
  static List<String> splitText(String text, int maximum) {
    final limit = maximum < 2 ? 4000 : maximum;
    final parts = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = (start + limit).clamp(0, text.length);
      if (end < text.length) {
        final code = text.codeUnitAt(end - 1);
        if (code >= 0xd800 && code <= 0xdbff) end--;
        final candidate = text.substring(start, end);
        final boundary = candidate.lastIndexOf(RegExp(r'[。！？；\n]'));
        if (boundary >= candidate.length ~/ 2) end = start + boundary + 1;
      }
      parts.add(text.substring(start, end));
      start = end;
    }
    return parts;
  }

  @override
  Future<SystemTtsOutcome> speak(
    String text, {
    double speed = 1,
    double pitch = 1,
    double volume = 1,
    String? voiceKey,
  }) {
    _cancelActive();
    _paused = null;
    final run = _Speech(++_generation, text, speed, pitch, volume)
      ..voiceOverride = voiceKey;
    run.onProgress = onProgress;
    _active = run;
    unawaited(_begin(run));
    return run.result.future;
  }

  @override
  Future<SystemTtsOutcome> resume() {
    final previous = _paused;
    if (previous == null) return Future.value(SystemTtsOutcome.cancelled);
    _paused = null;
    final run =
        _Speech(
            ++_generation,
            previous.text,
            previous.speed,
            previous.pitch,
            previous.volume,
          )
          ..voiceOverride = previous.voiceOverride
          ..parts = previous.parts
          ..index = previous.index
          ..partProgress = previous.partProgress
          ..partResumeOffset = supportsEngineSelection && previous.nativePaused
              ? previous.partProgress
              : 0
          ..onProgress = onProgress;
    _active = run;
    unawaited(_begin(run, resumeFrom: previous));
    return run.result.future;
  }

  Future<void> _begin(_Speech run, {_Speech? resumeFrom}) async {
    try {
      await _serialize(() async {
        await initialize();
        if (!_current(run)) return;
        if (resumeFrom?.nativePaused != true) await _stopNative();
        if (!_current(run)) return;
        // 起播重读目录用户标记；恢复原生暂停内容时不改变原 utterance 音色。
        if (resumeFrom?.nativePaused != true) {
          await _selectVoice(run.voiceOverride);
        }
        if (!_current(run)) return;
        _accept(
          await _plugin.setSpeechRate(
            speechRate(run.speed, _normalRate, _maxRate),
          ),
          '设置语速失败',
        );
        // 4.2.5 的 iOS 音调校验读取旧 volume，先恢复合法值再应用最终音量。
        await _plugin.setVolume(1.0);
        _accept(await _plugin.setPitch(run.pitch.clamp(0.5, 2.0)), '设置音调失败');
        _accept(await _plugin.setVolume(run.volume.clamp(0.0, 1.0)), '设置音量失败');
        run.parts ??= splitText(run.text, _maxLength);
        if (!_current(run)) return;
        if (run.parts!.isEmpty || run.index >= run.parts!.length) {
          _finish(run, SystemTtsOutcome.completed);
        } else {
          _speakPart(run);
        }
      });
    } catch (error, stack) {
      _finishError(run, error, stack);
    }
  }

  void _nativeProgress(String text, int start, int end, String word) {
    final run = _active;
    if (run == null ||
        !_current(run) ||
        _native == null ||
        run.parts == null ||
        run.index >= run.parts!.length) {
      return;
    }
    final part = run.parts![run.index];
    // 插件不暴露朗读 ID；停止屏障之外再核对实际送入的分片文本。
    final expected = part.substring(run.partResumeOffset.clamp(0, part.length));
    if (text != expected || start < 0 || end <= start || end > text.length) {
      return;
    }
    final base = run.parts!
        .take(run.index)
        .fold<int>(0, (sum, part) => sum + part.length);
    run.partProgress = run.partResumeOffset + start;
    run.onProgress?.call(
      base + run.partProgress,
      base + run.partResumeOffset + end,
    );
  }

  void _nativeFinished(SystemTtsOutcome outcome) {
    final pending = _native;
    _native = null;
    if (pending != null && !pending.isCompleted) pending.complete(outcome);
  }

  /// 停止后先收到原生的完成/取消确认才允许新朗读，隔离无 ID 的旧事件。
  Future<void> _stopNative() async {
    final pending = _native;
    if (_tts == null) return;
    await _plugin.stop();
    if (pending != null) {
      await pending.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw StateError('系统引擎未确认停止，请重试，已阻止启动重叠朗读'),
      );
    }
  }

  void _speakPart(_Speech run) {
    if (!_current(run)) return;
    run.started = true;
    final pending = _native ??= Completer<SystemTtsOutcome>();
    // 恢复 iOS 时复用同一原生 utterance；Android pause 已确认停止，重新续读。
    unawaited(
      _plugin
          .speak(run.parts![run.index], focus: false)
          .then(
            (value) {
              if (value != 1 && value != true && identical(_native, pending)) {
                _nativeFinished(SystemTtsOutcome.cancelled);
              }
            },
            onError: (Object error, StackTrace stack) {
              if (identical(_native, pending)) {
                _nativeFinished(SystemTtsOutcome.cancelled);
              }
              _finishError(run, error, stack);
            },
          ),
    );
    pending.future.then((outcome) {
      if (!_current(run)) {
        if (identical(_paused, run) && outcome == SystemTtsOutcome.completed) {
          run.index++;
          run.nativePaused = false;
        }
        return;
      }
      if (outcome != SystemTtsOutcome.completed) {
        _finishError(run, StateError('系统朗读已被中止'), StackTrace.current);
        return;
      }
      run.index++;
      run.partProgress = 0;
      run.partResumeOffset = 0;
      if (run.index == run.parts!.length) {
        _finish(run, SystemTtsOutcome.completed);
      } else {
        unawaited(_serialize(() async => _speakPart(run)));
      }
    });
  }

  @override
  Future<void> pause() {
    final run = _active;
    if (run == null) return Future.value();
    _paused = run;
    _active = null;
    _generation++;
    if (!run.result.isCompleted) run.result.complete(SystemTtsOutcome.paused);
    return _serialize(() async {
      final pending = _native;
      if (run.started && pending != null) {
        try {
          run.nativePaused = await _plugin.pause() == 1;
          if (supportsEngineSelection && run.nativePaused) {
            await pending.future.timeout(const Duration(seconds: 3));
          }
        } catch (_) {
          run.nativePaused = false;
        }
        if (!run.nativePaused) await _stopNative();
      }
    });
  }

  @override
  Future<void> stop() {
    _generation++;
    _cancelActive();
    _paused = null;
    return _serialize(() async {
      await _stopNative();
    });
  }

  @override
  Future<void> dispose() => stop();
  bool _current(_Speech run) =>
      identical(_active, run) && run.generation == _generation;
  void _cancelActive() {
    final old = _active;
    _active = null;
    if (old != null && !old.result.isCompleted) {
      old.result.complete(SystemTtsOutcome.cancelled);
    }
  }

  void _finish(_Speech run, SystemTtsOutcome outcome) {
    if (!_current(run)) return;
    _active = null;
    if (!run.result.isCompleted) run.result.complete(outcome);
  }

  void _finishError(_Speech run, Object error, StackTrace stack) {
    if (!_current(run)) return;
    _active = null;
    if (!run.result.isCompleted) run.result.completeError(error, stack);
  }
}

class _Speech {
  _Speech(this.generation, this.text, this.speed, this.pitch, this.volume);
  final int generation;
  final String text;
  final double speed, pitch, volume;
  final result = Completer<SystemTtsOutcome>();
  List<String>? parts;
  String? voiceOverride;
  int index = 0;
  bool started = false;
  bool nativePaused = false;
  int partProgress = 0;
  int partResumeOffset = 0;
  void Function(int start, int end)? onProgress;
}
