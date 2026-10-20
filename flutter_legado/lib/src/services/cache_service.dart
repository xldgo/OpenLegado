import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/contracts/cache_repository.dart';
import '../domain/models/cache_stats.dart';

/// 缓存管理服务
///
/// 提供缓存统计、清理功能；自动过期目前仅保存配置，执行入口待实现。
/// 对应 Android 原版 CacheBookService 中的缓存管理功能。
class CacheService {
  final CacheRepository _repository;

  /// 自动过期天数持久化键
  static const _keyAutoExpireDays = 'cache_auto_expire_days';

  CacheService(this._repository);

  /// 获取缓存统计信息
  ///
  /// 任一查询失败都向调用方报错，不拼出部分成功的统计。
  Future<CacheStats> getCacheStats() async {
    final totalSize = await _repository.getCacheSize();
    final bookCount = await _repository.getCacheBookCount();
    final chapterCount = await _repository.getCacheChapterCount();
    return CacheStats(
      totalSize: totalSize,
      bookCount: bookCount,
      chapterCount: chapterCount,
    );
  }

  /// 清除缓存
  ///
  /// [before] 若指定，则仅清除该时间之前的缓存；
  /// 若为 null，则清除全部缓存。
  /// 返回清除的缓存大小（字节）。
  Future<int> clearCache({DateTime? before}) async {
    final sizeBefore = await _repository.getCacheSize();
    if (before != null) {
      await _repository.clearCacheBefore(before.millisecondsSinceEpoch);
    } else {
      await _repository.clearCache();
    }
    final sizeAfter = await _repository.getCacheSize();
    final cleared = sizeBefore - sizeAfter;
    return cleared > 0 ? cleared : 0;
  }

  /// 清除章级「删除重复标题」开关的 SP 镜像键（Task #55 F4）
  ///
  /// Rust 侧全局清缓存（clearCache / clearCacheBefore）会复位 caches 表的
  /// sameTitleRemoved:* 章级开关，而阅读器顶栏的开关显示态依赖
  /// `sameTitleRemoved_{bookUrl}_{chapterIndex}` SP 镜像键辅助展示；
  /// 若不清理会造成显示态漂移（Rust 已复位而顶栏仍显示旧态）。
  /// 在「清除缓存」成功后的链路上调用本方法，顶栏下次加载自然回归默认态。
  /// 失败不阻断主流程（仅影响展示态，行为以 FFI 为准）。
  static Future<void> clearSameTitleRemovedFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (k) => k.startsWith('sameTitleRemoved_'),
      );
      for (final key in keys.toList()) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('CacheService.clearSameTitleRemovedFlags 异常: $e');
    }
  }

  /// 设置自动过期天数
  ///
  /// [days] 为 0 表示永不过期。
  Future<void> setAutoExpireDays(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyAutoExpireDays, days);
    } catch (e) {
      debugPrint('CacheService.setAutoExpireDays 异常: $e');
    }
  }

  /// 获取当前自动过期天数配置
  ///
  /// 返回 0 表示永不过期，默认值为 0。
  Future<int> getAutoExpireDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyAutoExpireDays) ?? 0;
    } catch (e) {
      debugPrint('CacheService.getAutoExpireDays 异常: $e');
      return 0;
    }
  }

  /// 格式化缓存大小为可读字符串
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
