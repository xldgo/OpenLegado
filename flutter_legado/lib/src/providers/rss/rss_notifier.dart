import '../rss_repository_provider.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

import '../../bridge/ffi.dart';
import '../../models/models.dart';
import '../../domain/contracts/rss_source_repository.dart';
import 'rss_state.dart';

export 'rss_state.dart';

/// 对齐 Android `LocalConfig.needUpRssSources` 的版本号
const kRssSourceVersionKey = 'rssSourceVersion';
const kRssSourceVersion = 6;

/// 默认订阅源资源路径（对齐 `app/src/main/assets/defaultData/rssSources.json`）
const kDefaultRssSourcesAsset = 'assets/default_data/rssSources.json';

/// 对齐 Android `DefaultData.importDefaultRssSources`：
/// 删除 `sourceGroup == legado` 后灌入 assets 默认源，返回导入条数。
///
/// [jsonOverride] 仅用于单测注入，生产路径传 null 走 assets。
Future<int> syncDefaultRssSources(
  RssSourceRepository repository, {
  String? jsonOverride,
}) async {
  final existing = await repository.getRssSources();
  for (final s in existing.where((e) => e.sourceGroup == 'legado')) {
    await repository.deleteRssSource(s.sourceUrl);
  }
  final text =
      jsonOverride ?? await rootBundle.loadString(kDefaultRssSourcesAsset);
  return repository.importRssSources(text);
}

/// RSS Riverpod Notifier
///
/// 迁移自原 RssProvider（ChangeNotifier）：忠实保留全部方法与错误处理语义，
/// 仅将 `notifyListeners()` 替换为 `state = state.copyWith(...)`。
/// - 调用订阅仓储 → 接收纯数据 → 更新 immutable State
/// - 管理源/文章加载状态（loading/error/data）
/// - 管理分组筛选（对齐安卓 RssFragment）
class RssNotifier extends Notifier<RssState> {
  @override
  RssState build() {
    // 原 RssProvider 构造时不自动加载，源列表由页面 initState 调用 loadSources 触发
    return const RssState();
  }

  // ===== 操作 =====

  /// 设置分组筛选；null 表示「全部」
  void setGroup(String? group) {
    state = state.copyWith(selectedGroup: group);
  }

  /// 加载所有 RSS 源列表
  Future<void> loadSources() async {
    state = state.copyWith(isLoadingSources: true, error: null);

    try {
      final repository = ref.read(rssSourceRepositoryProvider);
      await _ensureDefaultRssSources(repository);
      final sources = await repository.getRssSources();
      state = state.copyWith(sources: sources, isLoadingSources: false);
    } catch (e) {
      state = state.copyWith(error: _mapError(e), isLoadingSources: false);
    }
  }

  /// 首启/版本升级时导入默认订阅源（对标 DefaultData.upVersion + importDefaultRssSources）
  Future<void> _ensureDefaultRssSources(RssSourceRepository repository) async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(kRssSourceVersionKey) ?? 0;
    if (version >= kRssSourceVersion) return;

    await syncDefaultRssSources(repository);
    await prefs.setInt(kRssSourceVersionKey, kRssSourceVersion);
  }

  /// 菜单「导入默认」：立即覆盖 legado 分组（对齐 RssSourceViewModel.importDefault）
  Future<int> importDefaultSources() async {
    final repository = ref.read(rssSourceRepositoryProvider);
    final n = await syncDefaultRssSources(repository);
    final sources = await repository.getRssSources();
    state = state.copyWith(sources: sources, error: null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kRssSourceVersionKey, kRssSourceVersion);
    return n;
  }

  /// 选择源并加载文章
  Future<void> selectSource(RssSource source) async {
    state = state.copyWith(
      selectedSource: source,
      isLoadingArticles: true,
      error: null,
      articles: [],
    );

    try {
      final articles = await ref
          .read(rssArticleRepositoryProvider)
          .getRssArticles(source.sourceUrl);
      state = state.copyWith(articles: articles, isLoadingArticles: false);
    } catch (e) {
      state = state.copyWith(error: _mapError(e), isLoadingArticles: false);
    }
  }

  /// 刷新当前选中源的文章
  Future<void> refreshArticles() async {
    final source = state.selectedSource;
    if (source == null) return;
    await selectSource(source);
  }

  /// 清除已选源（返回源列表）
  void clearSelectedSource() {
    state = state.copyWith(selectedSource: null, articles: []);
  }

  /// 添加 RSS 源
  Future<void> addSource(String name, String url) async {
    state = state.copyWith(error: null);

    try {
      final newSource = RssSource(sourceUrl: url, sourceName: name);
      final added = await ref
          .read(rssSourceRepositoryProvider)
          .addRssSource(newSource);
      state = state.copyWith(sources: [...state.sources, added]);
    } catch (e) {
      state = state.copyWith(error: _mapError(e));
    }
  }

  /// 删除 RSS 源
  Future<void> removeSource(String sourceUrl) async {
    state = state.copyWith(error: null);

    try {
      await ref.read(rssSourceRepositoryProvider).deleteRssSource(sourceUrl);
      var next = state.copyWith(
        sources: state.sources.where((s) => s.sourceUrl != sourceUrl).toList(),
      );
      if (state.selectedSource?.sourceUrl == sourceUrl) {
        // 对齐原 clearSelectedSource：清除选中源与文章
        next = next.copyWith(selectedSource: null, articles: []);
      }
      state = next;
    } catch (e) {
      state = state.copyWith(error: _mapError(e));
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 统一错误映射（对齐原 BridgeError 优先取 message）
  String _mapError(Object e) {
    if (e is BridgeError) return e.message;
    return e.toString();
  }
}

/// RSS Notifier 全局 Provider
///
/// 使用方式：
/// ```dart
/// final state = ref.watch(rssNotifierProvider);
/// ref.read(rssNotifierProvider.notifier).loadSources();
/// ```
final rssNotifierProvider = NotifierProvider<RssNotifier, RssState>(
  RssNotifier.new,
);
