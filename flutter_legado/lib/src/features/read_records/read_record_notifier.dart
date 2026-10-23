import '../../utils/error_message.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../domain/contracts/read_record_settings_repository.dart';
import '../../providers/read_record_settings_provider.dart';
import 'read_record_state.dart';

/// 阅读记录 Riverpod Notifier（对齐原版 ReadRecordActivity）
///
/// 职责：管理搜索状态和共享偏好；列表与摘要由只读查询Provider负责。
class ReadRecordNotifier extends Notifier<ReadRecordState> {
  int _preferencesGeneration = 0;

  @override
  ReadRecordState build() {
    final repository = ref.watch(readRecordSettingsRepositoryProvider);
    final generation = ++_preferencesGeneration;
    final subscription = repository.watch().listen(
      (_) => _publishPreferences(repository, generation),
    );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return ReadRecordState(
      enableRecord: repository.current.enableRecord,
      displayMode: repository.current.displayMode,
      sortMode: repository.current.sortMode,
    );
  }

  void _publishPreferences(
    ReadRecordSettingsRepository repository,
    int generation,
  ) {
    if (!ref.mounted || generation != _preferencesGeneration) return;
    final settings = repository.current;
    state = state.copyWith(
      enableRecord: settings.enableRecord,
      displayMode: settings.displayMode,
      sortMode: settings.sortMode,
    );
  }

  Future<void> _savePreferences(
    Future<void> Function(ReadRecordSettingsRepository) save,
  ) async {
    final repository = ref.read(readRecordSettingsRepositoryProvider);
    final generation = _preferencesGeneration;
    try {
      final saving = save(repository);
      _publishPreferences(repository, generation);
      await saving;
    } finally {
      _publishPreferences(repository, generation);
    }
  }

  /// 加载共享偏好，不再额外查询和聚合原始记录。
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(readRecordSettingsRepositoryProvider);
      final generation = _preferencesGeneration;
      await repository.load();
      _publishPreferences(repository, generation);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: errorMessage(e));
    }
  }

  /// 展示偏好通过共享仓储即时生效，保存失败回退。
  Future<void> setDisplayMode(ReadRecordDisplayMode mode) =>
      _savePreferences((repository) => repository.update(displayMode: mode));

  /// 搜索（对齐原版 SearchView onQueryTextChange → initData）
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  /// 切换排序并持久化。
  Future<void> setSortMode(ReadRecordSortMode mode) =>
      _savePreferences((repository) => repository.update(sortMode: mode));

  /// 启用/关闭阅读时长记录，与阅读器共享同一来源。
  Future<void> toggleEnableRecord() => _savePreferences(
    (repository) =>
        repository.update(enableRecord: !repository.current.enableRecord),
  );
}

final readRecordNotifierProvider =
    NotifierProvider<ReadRecordNotifier, ReadRecordState>(
      ReadRecordNotifier.new,
    );
