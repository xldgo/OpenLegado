import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../domain/models/cache_stats.dart';
import '../providers/cache_provider.dart';
import '../services/cache_service.dart';

/// 缓存管理页面
///
/// 提供缓存统计显示、清理功能和自动过期策略配置。
/// 对应 Android 原版 CacheBookService 的缓存管理功能。
class CacheSettingsScreen extends ConsumerStatefulWidget {
  const CacheSettingsScreen({super.key});

  @override
  ConsumerState<CacheSettingsScreen> createState() =>
      _CacheSettingsScreenState();
}

class _CacheSettingsScreenState extends ConsumerState<CacheSettingsScreen> {
  late final CacheService _cacheService;

  /// 缓存统计加载状态
  bool _loading = true;

  /// 清理操作进行中标记
  bool _clearing = false;

  /// 仅在三项查询全部成功后替换快照，失败时保留最近成功结果。
  CacheStats? _stats;
  String? _statsError;

  /// 当前自动过期天数（0 = 永不过期）
  int _expireDays = 0;

  /// 过期策略选项
  static const List<Map<String, dynamic>> _expireOptions = [
    {'days': 7, 'label': '7 天'},
    {'days': 30, 'label': '30 天'},
    {'days': 0, 'label': '永不过期'},
  ];

  @override
  void initState() {
    super.initState();
    _cacheService = ref.read(cacheServiceProvider);
    _loadStats();
    _loadExpireDays();
  }

  /// 加载缓存统计数据
  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _statsError = null;
    });
    try {
      final stats = await _cacheService.getCacheStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statsError = '缓存统计读取失败：$error';
        });
      }
    }
  }

  /// 加载自动过期天数配置
  Future<void> _loadExpireDays() async {
    final days = await _cacheService.getAutoExpireDays();
    if (mounted) {
      setState(() => _expireDays = days);
    }
  }

  /// 显示清理确认对话框
  void _showClearConfirmDialog() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存数据吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        _doClearCache();
      }
    });
  }

  /// 执行缓存清理
  Future<void> _doClearCache() async {
    setState(() => _clearing = true);
    try {
      final cleared = await _cacheService.clearCache();
      // [Task #55 F4 | 2026-08-10] 清缓存成功后同步清除章级「删除重复
      // 标题」开关的 SP 镜像键，避免阅读器顶栏开关显示态漂移 — Qoder
      await CacheService.clearSameTitleRemovedFlags();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清除 ${CacheService.formatSize(cleared)} 缓存')),
        );
        await _loadStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('清除缓存失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }

  /// 处理过期策略变更
  Future<void> _onExpireDaysChanged(int? days) async {
    if (days == null) return;
    setState(() => _expireDays = days);
    await _cacheService.setAutoExpireDays(days);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('过期策略已更新')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(title: const Text('缓存管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              // [LAYOUT_PLAN P3] 页面水平边距16dp
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // ===== 缓存统计区域 =====
                _buildStatsSection(),
                const SizedBox(height: 12),
                // ===== 自动过期策略 =====
                _buildExpireSection(),
                const SizedBox(height: 12),
                // ===== 清理操作 =====
                _buildClearSection(),
              ],
            ),
    );
  }

  /// 构建缓存统计区域
  Widget _buildStatsSection() {
    // [LAYOUT_PLAN P3] 分组卡圆角16dp
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        // [LAYOUT_PLAN P3] 组内行 vertical12/horizontal8
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '缓存统计',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (_statsError case final error?) ...[
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(onPressed: _loadStats, child: const Text('重试')),
            ],
            if (_stats case final stats?)
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Symbols.storage_rounded,
                      label: '总大小',
                      value: CacheService.formatSize(stats.totalSize),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Symbols.menu_book_rounded,
                      label: '书籍数量',
                      value: '${stats.bookCount}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Symbols.article_rounded,
                      label: '章节数量',
                      value: '${stats.chapterCount}',
                    ),
                  ),
                ],
              ),
          ],
          // [LAYOUT_PLAN P3] 分组卡圆角16dp 闭合
        ),
      ),
    );
  }

  /// 构建单个统计卡片
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    // [LAYOUT_PLAN P3] 列表行字级走 M3 Type Scale
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              // [LAYOUT_PLAN P3] 列表行字级走 M3 Type Scale
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              // [LAYOUT_PLAN P3] 列表行字级走 M3 Type Scale
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建自动过期策略配置区域
  Widget _buildExpireSection() {
    // [LAYOUT_PLAN P3] 分组卡圆角16dp
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        // [LAYOUT_PLAN P3] 组内行 vertical12/horizontal8
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '自动过期策略',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownMenuFormField<int>(
              initialSelection: _expireDays,
              selectOnly: true,
              expandedInsets: EdgeInsets.zero,
              leadingIcon: const Icon(Symbols.schedule_rounded),
              label: const Text('缓存过期时间'),
              dropdownMenuEntries: _expireOptions.map((option) {
                return DropdownMenuEntry<int>(
                  value: option['days'] as int,
                  label: option['label'] as String,
                );
              }).toList(),
              onSelected: _onExpireDaysChanged,
            ),
            const SizedBox(height: 8),
            Text(
              '超过设定时间的缓存将在下次启动时自动清除',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          // [LAYOUT_PLAN P3] 分组卡圆角16dp 闭合
        ),
      ),
    );
  }

  /// 构建清理操作区域
  Widget _buildClearSection() {
    // [LAYOUT_PLAN P3] 分组卡圆角16dp
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        // [LAYOUT_PLAN P3] 组内行 vertical12/horizontal8
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '清理操作',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearing ? null : _showClearConfirmDialog,
                icon: _clearing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Symbols.cleaning_services_rounded,
                        // [LAYOUT_PLAN P3] 状态色走 tonal
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                label: Text(
                  _clearing ? '清理中...' : '清除全部缓存',
                  // [LAYOUT_PLAN P3] 状态色走 tonal
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  // [LAYOUT_PLAN P3] 状态色走 tonal
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.errorContainer,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          // [LAYOUT_PLAN P3] 分组卡圆角16dp 闭合
        ),
      ),
    );
  }
}
