import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/book_source_repository.dart';
import '../../providers/providers.dart';

/// 分享根实例的同一书源数据访问，跟随根替换而不触发初始化。— Codex + UI
final bookSourceRepositoryProvider = Provider<BookSourceRepository>(
  (ref) => ref.watch(bookApiProvider).bookSourceRepository,
);
