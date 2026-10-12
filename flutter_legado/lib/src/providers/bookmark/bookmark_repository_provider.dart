import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/bookmark_repository.dart';
import '../providers.dart';

/// 共享根实例装配的 Repository；不识别具体实现或另建存储。— Codex + UI
final bookmarkRepositoryProvider = Provider<BookmarkRepository>(
  (ref) => ref.watch(bookApiProvider).bookmarkRepository,
);
