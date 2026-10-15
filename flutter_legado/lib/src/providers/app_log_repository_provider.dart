import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/app_log_repository.dart';
import 'providers.dart';

/// 页面、搜索和换源共用同一装配仓储，可独立替换。— Codex + UI
final appLogRepositoryProvider = Provider<AppLogRepository>(
  (ref) => ref.watch(bookApiProvider).appLogRepository,
);
