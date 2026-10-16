import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/reading_content_service.dart';
import 'providers.dart';

/// 正文处理与普通阅读偏好分别注入。— Codex + UI
final readingContentServiceProvider = Provider<ReadingContentService>(
  (ref) => ref.watch(bookApiProvider).readingContentService,
);
