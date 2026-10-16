import '../app_log_repository_provider.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../bridge/ffi.dart';
import '../../models/models.dart';
import '../../domain/contracts/source_switch_service.dart';
import 'source_switch_dependencies.dart';
import '../../features/book_sources/book_source_repository_provider.dart';
import 'change_source_state.dart';

export 'change_source_state.dart';

/// 换源页 Riverpod Notifier
///
/// 职责严格限定（对齐 UI_RESTRUCTURE_PLAN.md §0.2 铁律）：
/// - 调用 SourceSwitchService.searchSourceStream → 逐批接收 Rust 已评分排序的候选快照 → 更新 immutable State
/// - 调用 SourceSwitchService.switchSource 完成书源切换并回写 Rust
/// - 管理 UI 状态（loading/error/results/applying 四态）
/// - 禁止包含匹配/评分/排序逻辑（由 Rust SourceMatcher 完成）
class ChangeSourceNotifier extends Notifier<ChangeSourceState> {
  /// 搜索序列号：仅最新一轮的批次允许更新状态（seq guard，与
  /// SearchNotifier._searchSeq 同构；旧流丢弃即触发 Rust 侧 sink 关闭取消）
  int _searchSeq = 0;
  SourceSwitchService? _applyingService;

  @override
  ChangeSourceState build() {
    ref.onDispose(() => _searchSeq++);
    return const ChangeSourceState();
  }

  /// 搜索可替换书源（T6 流式：逐源渐进渲染）
  ///
  /// 消费 [SourceSwitchService.searchSourceStream] 的逐源批次：每批 `matches` 为当前已
  /// 过滤评分候选的**全量快照**，直接替换展示；`finished_count`/`total_count`
  /// 驱动 x/y 进度文案。单源失败仅 AppLog 留痕（对齐 SearchNotifier），
  /// 末批错误且无结果时才置 error 态。
  ///
  /// [UI-fix v2.0.3 | 2026-08-06] 留项#12（Task #131）：[group] 参数非空时
  /// 用 getEnabledBookSources() 内存过滤出该分组源 URL 列表传给流式搜索
  /// （对齐原版 AppConfig.searchGroup 分组搜索）；分组下无启用源时直接
  /// 返回空结果，不误搜全部 — Qoder
  Future<void> search(
    String bookName,
    String author, {
    String group = '',
    bool loadInfo = false,
    bool loadToc = false,
    bool loadWordCount = false,
    bool forceRefresh = false,
  }) async {
    if (state.isLoading) return;
    final seq = ++_searchSeq;
    state = state.copyWith(
      isLoading: true,
      error: null,
      searchingCount: null,
      progressFinished: null,
      progressTotal: null,
    );
    try {
      List<String>? sourceUrls;
      if (group.isNotEmpty) {
        final sources = await ref
            .read(bookSourceRepositoryProvider)
            .getEnabledBookSources();
        sourceUrls = sources
            .where((s) {
              final g = s.bookSourceGroup ?? '';
              if (g.trim().isEmpty) return false;
              // [审计 D1 | SearchBookDao.kt:13-32] 分组分隔符全集 ,;，；，
              // 与原版 splitGroupRegex 对齐（仅逗号会漏分号分组的源）
              return g
                  .split(RegExp(r'[,;，；]'))
                  .map((e) => e.trim())
                  .contains(group);
            })
            .map((s) => s.bookSourceUrl)
            .toList();
        if (sourceUrls.isEmpty) {
          // 所选分组无启用书源：直接空结果（不误搜全部）
          state = state.copyWith(
            results: [],
            isLoading: false,
            searchingCount: null,
          );
          return;
        }
      }
      if (seq != _searchSeq) return;
      // 先取得本轮参与搜索的源数量供 UI 展示等待反馈（T6：进度 x/y 的 y
      // 权威值改由批次 total_count 提供，此计数仅作流启动前的占位）
      var searchingCount = sourceUrls?.length ?? 0;
      if (sourceUrls == null) {
        try {
          searchingCount =
              (await ref
                      .read(bookSourceRepositoryProvider)
                      .getEnabledBookSources())
                  .length;
        } catch (_) {
          searchingCount = 0;
        }
      }
      state = state.copyWith(searchingCount: searchingCount);

      // T6：逐源流式消费——每批快照直接替换展示，不重排（评分排序由 Rust
      // SourceMatcher + rank_candidates_with_options 完成）
      String? terminalError;
      await for (final batch
          in ref
              .read(sourceSwitchServiceProvider)
              .searchSourceStream(
                bookName,
                author,
                sourceUrls: sourceUrls,
                loadInfo: loadInfo,
                loadToc: loadToc,
                loadWordCount: loadWordCount,
                forceRefresh: forceRefresh,
              )) {
        if (!ref.mounted || seq != _searchSeq) return;
        final batchError = batch.error;
        if (batchError != null && batchError.isNotEmpty) {
          // 单源失败静默不弹 UI、仅 AppLog 留痕（对齐 SearchNotifier 批次
          // error 处理）；末批错误记为终态错误，无结果时展示
          unawaited(
            Future<void>.sync(
              () => ref
                  .read(appLogRepositoryProvider)
                  .appLogPush(
                    level: 'message',
                    message:
                        '换源搜索出错\n${batch.sourceName.isEmpty ? '未知书源' : batch.sourceName}: $batchError',
                  ),
            ).catchError((_) {}),
          );
          if (batch.isLast) terminalError = batchError;
        }
        state = state.copyWith(
          results: batch.matches,
          progressFinished: batch.finishedCount,
          progressTotal: batch.totalCount,
          // 2026-09-24 换源感知等待：记录最后完成的源名（对齐上游
          // changeSourceProgress 的 (count, name) 发射，Dialog L286-298）
          progressLastSourceName: batch.sourceName,
        );
      }
      if (!ref.mounted || seq != _searchSeq) return;
      state = state.copyWith(
        error: (terminalError != null && state.results.isEmpty)
            ? terminalError
            : null,
        isLoading: false,
        searchingCount: null,
        progressFinished: null,
        progressTotal: null,
        progressLastSourceName: null,
      );
    } catch (e) {
      if (!ref.mounted || seq != _searchSeq) return;
      state = state.copyWith(
        error: _mapError(e),
        isLoading: false,
        searchingCount: null,
        progressFinished: null,
        progressTotal: null,
        progressLastSourceName: null,
      );
    }
  }

  /// 应用选中的书源，返回切换后仍保持的书籍主键
  ///
  /// 经 [SourceSwitchService.switchSourcePrefetch]（预拉缓存版，2026-09-24 换源感知
  /// 等待）回写 Rust：命中搜索期预拉缓存 → 零网络直接落地；未命中 →
  /// 现场抓取（可经 [cancelApply] 取消）。返回数据层解码的稳定书籍主键，
  /// 失败时原样抛出异常，
  /// 由 UI 侧展示错误提示。
  Future<String> applySource(
    SourceMatch match, {
    required String bookUrl,
  }) async {
    if (state.isApplying) {
      throw StateError('已有换源操作进行中');
    }
    state = state.copyWith(applyingUrl: match.sourceUrl);
    final service = ref.read(sourceSwitchServiceProvider);
    _applyingService = service;
    try {
      final updated = await service.switchSourcePrefetch(
        bookUrl,
        match.sourceUrl,
        match.bookUrl,
      );
      return updated.bookUrl;
    } finally {
      _applyingService = null;
      if (ref.mounted) state = state.copyWith(applyingUrl: null);
    }
  }

  /// 取消进行中的「换源（预拉缓存版）」应用（对齐上游 cancelChangeSource，
  /// ChangeBookSourceViewModel.kt L715-721）
  ///
  /// Rust 侧 apply 代数 +1 并 bump 目录刷新代数：未提交的 apply 在提交前
  /// 代数比对即中止（DB 零变更），在途目录分页链在下一页边界中止。
  Future<void> cancelApply() {
    final SourceSwitchService service =
        _applyingService ?? ref.read(sourceSwitchServiceProvider);
    return service.cancelSwitchSourceApply();
  }

  /// 统一错误映射
  String _mapError(Object e) {
    if (e is BridgeError) return e.message;
    return e.toString();
  }

  /// 更新换源列表项用户评分（-1/0/1），持久化后同步本地状态
  Future<void> updateBookScore(String bookUrl, int score) async {
    await ref
        .read(sourceSwitchServiceProvider)
        .updateSearchBookScore(bookUrl, score);
    final results = [...state.results];
    final idx = results.indexWhere((r) => r.bookUrl == bookUrl);
    if (idx < 0) return;
    results[idx] = results[idx].copyWith(bookScore: score);
    state = state.copyWith(results: results);
  }

  /// 置顶：本地重排至列表首位（对标原版 topSource）
  void moveToTop(String bookUrl) {
    final results = List<SourceMatch>.from(state.results);
    final idx = results.indexWhere((r) => r.bookUrl == bookUrl);
    if (idx <= 0) return;
    final item = results.removeAt(idx);
    results.insert(0, item);
    state = state.copyWith(results: results);
  }

  /// 置底：本地重排至列表末位（对标原版 bottomSource）
  void moveToBottom(String bookUrl) {
    final results = List<SourceMatch>.from(state.results);
    final idx = results.indexWhere((r) => r.bookUrl == bookUrl);
    if (idx < 0 || idx >= results.length - 1) return;
    final item = results.removeAt(idx);
    results.add(item);
    state = state.copyWith(results: results);
  }

  /// 禁用书源并从列表移除
  Future<void> disableAndRemove(SourceMatch match) async {
    await ref
        .read(bookSourceRepositoryProvider)
        .disableBookSource(match.sourceUrl);
    state = state.copyWith(
      results: state.results.where((r) => r.bookUrl != match.bookUrl).toList(),
    );
  }

  /// 删除换源列表项；返回被删项（供 UI 判断是否当前源）
  Future<SourceMatch?> deleteSearchBookItem(String bookUrl) async {
    await ref.read(sourceSwitchServiceProvider).deleteSearchBook(bookUrl);
    final results = List<SourceMatch>.from(state.results);
    final idx = results.indexWhere((r) => r.bookUrl == bookUrl);
    if (idx < 0) return null;
    final removed = results.removeAt(idx);
    state = state.copyWith(results: results);
    return removed;
  }
}

/// 换源页 Notifier 全局 Provider
///
/// 使用方式：
/// ```dart
/// final state = ref.watch(changeSourceNotifierProvider);
/// ref.read(changeSourceNotifierProvider.notifier).search(bookName, author);
/// ```
final changeSourceNotifierProvider =
    NotifierProvider<ChangeSourceNotifier, ChangeSourceState>(
      ChangeSourceNotifier.new,
    );
