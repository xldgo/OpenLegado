// [UI-fix v2.0.3 | 2026-08-08] 留项10：定时服务应用内调度器（Task #146）。
// 对齐 Kotlin 原版 service/AutoTaskScheduler + AutoTaskJobService +
// AutoTaskSchedulePolicy：refresh 触发点（启动/任务变更/开关）、executionLock
// 串行批次、jobFinished(retry) 退避重试语义。应用内 Timer 调度（非真后台
// WorkManager，进程被杀后不执行，属诚实边界）。 — QoderCN
import 'dart:async';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/contracts/auto_task_repository.dart';
import '../domain/contracts/auto_task_service.dart';
import '../models/misc.dart';

/// 定时任务应用内调度器（应用装配注入窄依赖）
///
/// 与 Kotlin 原版组件的对应关系：
/// | Kotlin 原版                            | 本实现                                |
/// |----------------------------------------|---------------------------------------|
/// | AutoTaskScheduler.refresh              | [refresh]                             |
/// | PreferKey.autoTaskService 开关         | config 键 `autoTaskService`           |
/// | AutoTaskSchedulePolicy.nextDueAt       | [_nextRunAt]（经 autoTaskNextDueAt）  |
/// | AutoTaskSchedulePolicy.dueRules        | [_dueRules]                           |
/// | FIRST_RUN_GRACE_MS（5 分钟宽限）        | [_firstRunGrace]                      |
/// | JobScheduler.setMinimumLatency         | [Timer]                               |
/// | AutoTaskJobService.executionLock       | [_running]（重复触发跳过）             |
/// | jobFinished(retry=true)+BACKOFF 60s    | [_retryBackoff] 退避重试               |
/// | AutoTaskScheduler.cancelAll            | [cancelAll]                           |
///
/// 触发点（对齐原版 refresh 调用位置）：
/// - 应用启动：app.dart 装配 [attach]
/// - 任务增删改 / 启停：auto_task_screen 操作后调用 [refresh]
/// - 设置页开关：开启 → [refresh]，关闭 → [cancelAll]（settings_screen）
/// - 应用自后台恢复：[didChangeAppLifecycleState] resumed → [refresh]
class AutoTaskScheduler with WidgetsBindingObserver {
  AutoTaskScheduler({int Function()? nowMs}) : _nowMs = nowMs ?? _systemNowMs;

  static int _systemNowMs() => DateTime.now().millisecondsSinceEpoch;
  final int Function() _nowMs;

  /// 全局单例（对齐 PlatformBridgeService.instance 模式）
  static final AutoTaskScheduler instance = AutoTaskScheduler();

  /// 失败退避重试间隔（对齐 Kotlin RETRY_BACKOFF_MS = 60_000）
  static const Duration _retryBackoff = Duration(minutes: 1);

  /// 首次运行宽限期（对齐 AutoTaskSchedulePolicy.FIRST_RUN_GRACE_MS）
  static const Duration _firstRunGrace = Duration(minutes: 5);

  AutoTaskRepository? _repository;
  AutoTaskService? _service;
  Future<bool> Function()? _readEnabled;

  /// 当前挂起的调度 Timer（对标 JobScheduler pending job）
  Timer? _timer;

  /// 串行执行锁（对标 executionLock Mutex）：同一时刻仅一批执行，
  /// 重复触发直接跳过。Dart 单线程事件循环保证标志位读写原子性。
  bool _running = false;

  /// 刷新代数：并发的 [refresh] 互相作废旧一代的延迟结果
  int _generation = 0;
  int _attachment = 0;

  static const MethodChannel _jobChannel = MethodChannel(
    'legado/auto_task_job',
  );
  bool _jobHandlerBound = false;

  /// 装配入口（app.dart initState，参考 PlatformBridgeService.navigatorKey）
  ///
  /// 注入规则仓储、任务服务与开关读取，并注册生命周期观察（后台恢复时重算调度），
  /// 随后执行一次 [refresh]（对齐原版 App.kt 启动触发点）。
  void attach({
    required AutoTaskRepository repository,
    required AutoTaskService service,
    required Future<bool> Function() readEnabled,
  }) {
    detach();
    _repository = repository;
    _service = service;
    _readEnabled = readEnabled;
    WidgetsBinding.instance.addObserver(this);
    _bindJobChannel();
    refresh();
  }

  void _bindJobChannel() {
    if (_jobHandlerBound || !Platform.isAndroid) return;
    _jobHandlerBound = true;
    _jobChannel.setMethodCallHandler((call) async {
      if (call.method == 'onJobDue') {
        await _onTimer();
      }
    });
  }

  Future<void> _syncNativeSchedule(Duration delay) async {
    if (!Platform.isAndroid) return;
    try {
      await _jobChannel.invokeMethod('schedule', {
        'delayMs': delay.inMilliseconds.clamp(0, 1 << 30),
      });
    } catch (e) {
      debugPrint('[AutoTaskScheduler] JobScheduler schedule failed: $e');
    }
  }

  Future<void> _cancelNativeSchedule() async {
    if (!Platform.isAndroid) return;
    try {
      await _jobChannel.invokeMethod('cancelAll');
    } catch (e) {
      debugPrint('[AutoTaskScheduler] JobScheduler cancel failed: $e');
    }
  }

  /// 应用自后台恢复：Timer 在挂起期间可能已过期，重算一次调度
  ///（对齐原版「启动时 refresh」的最接近应用内等价物）。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  /// 是否处于开启状态（读持久化开关，对齐 getPrefBoolean(autoTaskService)）
  Future<bool> _isEnabled() async {
    final readEnabled = _readEnabled;
    if (readEnabled == null) return false;
    try {
      return await readEnabled();
    } catch (_) {
      return false;
    }
  }

  /// 取消全部挂起调度（对标 AutoTaskScheduler.cancelAll）
  Future<void> cancelAll() async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    await _cancelNativeSchedule();
  }

  /// 释放应用内观察与计时器；不改动原生持久任务和用户开关。— Codex + UI
  void detach() {
    _attachment++;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _repository = null;
    _service = null;
    _readEnabled = null;
    WidgetsBinding.instance.removeObserver(this);
    if (_jobHandlerBound) _jobChannel.setMethodCallHandler(null);
    _jobHandlerBound = false;
  }

  /// 重算调度（对标 AutoTaskScheduler.refresh）
  ///
  /// [afterBatch] 为 true 时以当前时间为基准计算下次执行
  ///（对标 nextAfterBatchAt），否则以各任务 lastRunAt / 宽限期为基准
  ///（对标 nextDueAt）。开关关闭或无可调度任务时取消挂起 Timer。
  Future<void> refresh({bool afterBatch = false}) async {
    final repository = _repository;
    final service = _service;
    if (repository == null || service == null) return;
    final generation = ++_generation;
    try {
      final enabled = await _isEnabled();
      if (generation != _generation) return;
      if (!enabled) {
        _timer?.cancel();
        _timer = null;
        await _cancelNativeSchedule();
        return;
      }
      final rules = await repository.listRules();
      if (generation != _generation) return; // 已被更新的 refresh 取代
      final now = _nowMs();
      final runAt = await _nextRunAt(
        service,
        rules,
        now,
        afterBatch: afterBatch,
      );
      if (generation != _generation) return;
      _timer?.cancel();
      _timer = null;
      if (runAt == null) return;
      final delay = Duration(milliseconds: (runAt - now).clamp(0, 1 << 62));
      _timer = Timer(delay, _onTimer);
      await _syncNativeSchedule(delay);
      debugPrint(
        '[AutoTaskScheduler] 下次执行：${DateTime.fromMillisecondsSinceEpoch(runAt)}'
        '（${delay.inSeconds}s 后）',
      );
    } catch (e) {
      // FFI 暂不可用（引擎未就绪等）不抛出；开关/任务变更会再次触发
      debugPrint('[AutoTaskScheduler] refresh 失败: $e');
    }
  }

  /// 计算最近一次到期时间（对标 nextDueAt / nextAfterBatchAt）
  ///
  /// 逐任务经 autoTaskNextDueAt(cron, base) 计算，base 取：
  /// - afterBatch：当前时间（严格在 now 之后的下次触发）
  /// - 常规：lastRunAt > 0 时取 lastRunAt，否则 now - 宽限期（首次运行）
  /// 返回 null 表示无可调度任务（全部禁用 / cron 无效）。
  Future<int?> _nextRunAt(
    AutoTaskService service,
    List<AutoTaskRule> rules,
    int now, {
    required bool afterBatch,
  }) async {
    int? min;
    for (final rule in rules) {
      if (!_ruleEnabled(rule)) continue;
      final cron = (rule.cron ?? '').trim();
      if (cron.isEmpty) continue;
      final base = afterBatch ? now : _baseTime(rule, now);
      int nextDue;
      try {
        nextDue = await service.nextDueAt(cron: cron, fromMs: base);
      } catch (_) {
        continue;
      }
      if (nextDue < 0) continue; // cron 无法解析
      final candidate = nextDue < now ? now : nextDue; // coerceAtLeast(now)
      if (min == null || candidate < min) min = candidate;
    }
    return min;
  }

  /// 筛出到期任务（对标 AutoTaskSchedulePolicy.dueRules）
  ///
  /// 判定：nextTimeAfter(base) <= now，base 规则同 [_nextRunAt] 常规分支。
  Future<List<AutoTaskRule>> _dueRules(
    AutoTaskService service,
    List<AutoTaskRule> rules,
    int now,
  ) async {
    final due = <AutoTaskRule>[];
    for (final rule in rules) {
      if (!_ruleEnabled(rule)) continue;
      final cron = (rule.cron ?? '').trim();
      if (cron.isEmpty) continue;
      int nextDue;
      try {
        nextDue = await service.nextDueAt(
          cron: cron,
          fromMs: _baseTime(rule, now),
        );
      } catch (_) {
        continue;
      }
      if (nextDue >= 0 && nextDue <= now) due.add(rule);
    }
    return due;
  }

  /// 基准时间（对标 baseTime：lastRunAt>0 取之，否则 now - 宽限期）
  int _baseTime(AutoTaskRule rule, int now) =>
      rule.lastRunAt > 0 ? rule.lastRunAt : now - _firstRunGrace.inMilliseconds;

  bool _ruleEnabled(AutoTaskRule rule) => rule.enable;

  /// Timer 到点回调：执行一批到期任务（对标 onStartJob）
  Future<void> _onTimer() async {
    // executionLock 语义：已有批次执行中则跳过本次触发
    if (_running) return;
    final repository = _repository;
    final service = _service;
    if (repository == null || service == null) return;
    _running = true;
    final attachment = _attachment;
    bool attached() =>
        attachment == _attachment &&
        identical(_repository, repository) &&
        identical(_service, service);
    try {
      if (!await _isEnabled() || !attached()) return;
      final rules = await repository.listRules();
      if (!attached()) return;
      final now = _nowMs();
      final due = await _dueRules(service, rules, now);
      if (!attached()) return;
      if (due.isEmpty) {
        // 无到期任务：按批次后策略重排下一轮（对标 shouldRetry 分支）
        await refresh(afterBatch: true);
        return;
      }
      for (final rule in due) {
        if (!attached()) return;
        // 单任务失败不影响整批（对标 runTask 逐任务 try/catch 持久化）
        try {
          final id = rule.id;
          final protocol = <String, dynamic>{
            'action': rule.comment ?? 'noop',
            'taskId': id,
          };
          await service.execute(protocol: protocol, taskId: id);
          debugPrint('[AutoTaskScheduler] 任务执行完成: ${rule.name}');
        } catch (e) {
          debugPrint('[AutoTaskScheduler] 任务执行失败: ${rule.name} — $e');
        }
      }
      // 批次完成：以当前时间为基准调度下一轮（对标 refresh(afterBatch=true)）
      if (attached()) await refresh(afterBatch: true);
    } catch (e) {
      // 批次级失败（FFI 异常等）：退避重试（对标 jobFinished(retry=true)
      // + BACKOFF_POLICY_LINEAR 60s）
      debugPrint(
        '[AutoTaskScheduler] 批次执行失败，${_retryBackoff.inSeconds}s 后重试: $e',
      );
      if (!attached()) return;
      _generation++;
      _timer?.cancel();
      _timer = Timer(_retryBackoff, _onTimer);
    } finally {
      _running = false;
    }
  }
}
