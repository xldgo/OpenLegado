import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/tts_cache_repository.dart';
import 'tts_providers.dart';

/// 缓存页状态只依赖窄接口，不访问播放器或文件系统。— Codex + UI
final ttsCacheProvider =
    AsyncNotifierProvider<TtsCacheNotifier, List<TtsCacheEntry>>(
      TtsCacheNotifier.new,
    );

class TtsCacheNotifier extends AsyncNotifier<List<TtsCacheEntry>> {
  @override
  Future<List<TtsCacheEntry>> build() =>
      ref.watch(ttsCacheRepositoryProvider).list();
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ttsCacheRepositoryProvider).list(),
    );
  }

  Future<TtsCacheClearResult> clear({String? name}) async {
    final result = await ref.read(ttsCacheRepositoryProvider).clear(name: name);
    await reload();
    return result;
  }
}
