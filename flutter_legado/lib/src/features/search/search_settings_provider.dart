import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_search_settings_repository.dart';
import '../../domain/contracts/search_settings_repository.dart';
import '../../domain/models/search_settings.dart';
import '../../providers/app_settings_provider.dart';

final searchSettingsRepositoryProvider = Provider<SearchSettingsRepository>(
  (ref) => AppSearchSettingsRepository(ref.watch(appSettingsServiceProvider)),
);

/// 当前值由共享设置服务拥有；Provider 只负责订阅与生命周期。— Codex + UI
final searchSettingsProvider = StreamProvider<SearchSettings>((ref) {
  final repository = ref.watch(searchSettingsRepositoryProvider);
  return Stream.multi((controller) {
    var active = true;
    final subscription = repository.watch().listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    // 先订阅再加载，首次读取未完成时的用户修改也能即时显示。
    unawaited(
      repository.load().then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          if (active) controller.addError(error, stackTrace);
        },
      ),
    );
    controller.onCancel = () {
      active = false;
      return subscription.cancel();
    };
  });
});
