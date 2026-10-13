import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/book_group_repository.dart';
import '../../domain/contracts/bookshelf_repository.dart';
import '../../providers/providers.dart';

/// 共用根 BookApi 的唯一数据源，不触发运行时或数据库初始化。— Codex + UI
final bookshelfRepositoryProvider = Provider<BookshelfRepository>(
  (ref) => ref.watch(bookApiProvider).bookshelfRepository,
);

final bookGroupRepositoryProvider = Provider<BookGroupRepository>(
  (ref) => ref.watch(bookApiProvider).bookGroupRepository,
);
