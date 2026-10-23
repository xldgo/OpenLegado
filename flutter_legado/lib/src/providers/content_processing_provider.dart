import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_content_processing_settings_repository.dart';
import '../domain/contracts/content_processing_settings_repository.dart';
import '../models/book.dart';
import 'app_settings_provider.dart';
import 'reading_provider.dart';

final contentProcessingSettingsRepositoryProvider =
    Provider<ContentProcessingSettingsRepository>(
      (ref) => AppContentProcessingSettingsRepository(
        ref.watch(appSettingsServiceProvider),
      ),
    );

/// 处理正文的消费者等待保存队列完成，避免读取尚未写入 Rust 的乐观值。— Codex + UI
final replaceEnableDefaultProvider = StreamProvider<bool>((ref) async* {
  final repository = ref.watch(contentProcessingSettingsRepositoryProvider);
  await repository.load();
  await for (final _ in repository.watch()) {
    await repository.settled();
    yield repository.current;
  }
});

/// 菜单使用 Rust 的有效值；加载失败保持错误态，不在 UI 复制书籍类型规则。
final effectiveReplaceRuleProvider = FutureProvider.autoDispose
    .family<bool, Book>((ref, book) async {
      final repository = ref.watch(readingRepositoryProvider);
      final defaultEnabled = await ref.watch(
        replaceEnableDefaultProvider.future,
      );
      return repository.resolveReplaceRule(book, defaultEnabled);
    });
