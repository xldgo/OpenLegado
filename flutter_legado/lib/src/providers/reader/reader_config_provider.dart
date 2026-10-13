import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/preferences_reader_config_repository.dart';
import '../../domain/contracts/reader_config_repository.dart';
import '../../models/reader_advanced_config.dart';

final readerConfigRepositoryProvider = Provider<ReaderConfigRepository>(
  (ref) => PreferencesReaderConfigRepository(),
);

/// 配置只在共享入口加载一次，界面即时更新，存储按操作顺序保存快照。
class ReaderAdvConfigNotifier extends Notifier<ReaderAdvancedConfig?> {
  late ReaderConfigRepository _repository;
  Future<ReaderAdvancedConfig>? _loading;
  bool _disposed = false;
  int _generation = 0;

  @override
  ReaderAdvancedConfig? build() {
    _repository = ref.watch(readerConfigRepositoryProvider);
    _disposed = false;
    final generation = ++_generation;
    _loading = null;
    ref.onDispose(() => _disposed = true);
    Future.microtask(() async {
      if (_disposed || generation != _generation) return;
      try {
        await ensureLoaded();
      } catch (error) {
        if (!_disposed && generation == _generation) {
          debugPrint('阅读配置加载失败: $error');
        }
      }
    });
    return null;
  }

  Future<ReaderAdvancedConfig> ensureLoaded() {
    if (state case final current?) return Future.value(current.copy());
    return _loading ??= _load(_generation, _repository);
  }

  Future<ReaderAdvancedConfig> _load(
    int generation,
    ReaderConfigRepository repository,
  ) async {
    try {
      final loaded = await repository.load();
      if (_disposed || generation != _generation) return loaded.copy();
      state ??= loaded.copy();
      return state!.copy();
    } finally {
      if (!_disposed && generation == _generation) _loading = null;
    }
  }

  /// 可等待的统一提交入口；失败交回调用方，保留即时界面状态。
  Future<void> commit(ReaderAdvancedConfig config) {
    final snapshot = config.copy();
    state = snapshot.copy();
    return _repository.save(snapshot);
  }

  /// 页面无需等待磁盘写入；失败记录诊断，不产生未处理异步异常。
  void update(ReaderAdvancedConfig config) {
    unawaited(
      commit(config).catchError((Object error) {
        debugPrint('阅读配置保存失败: $error');
      }),
    );
  }
}

final readerAdvConfigProvider =
    NotifierProvider<ReaderAdvConfigNotifier, ReaderAdvancedConfig?>(
      ReaderAdvConfigNotifier.new,
    );
