import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/explore/explore_dependencies.dart';
import '../../../providers/network_provider.dart';
import '../../book_sources/book_source_repository_provider.dart';
import '../../search/search_access_providers.dart';
import '../bookshelf_notifier.dart';
import '../bookshelf_repositories.dart';
import 'bookshelf_import_controller.dart';

/// 装配现有能力；运行中不依赖页面生命周期，也不触发额外原生初始化。— Codex + UI
final bookshelfImportControllerProvider = Provider<BookshelfImportController>(
  (ref) => BookshelfImportController(
    bookshelf: ref.watch(bookshelfRepositoryProvider),
    sources: ref.watch(bookSourceRepositoryProvider),
    sourceQuery: ref.watch(bookSourceQueryServiceProvider),
    search: ref.watch(searchServiceProvider),
    network: ref.watch(networkServiceProvider),
    currentBooks: () => ref.read(bookshelfNotifierProvider).books,
    log: debugPrint,
  ),
);
