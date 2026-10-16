import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/auto_task_repository.dart';
import '../../domain/contracts/auto_task_service.dart';
import '../providers.dart';

/// 自动任务窄依赖可独立替换；服务缺失由异常反馈。— Codex + UI
final autoTaskRepositoryProvider = Provider<AutoTaskRepository>(
  (ref) => ref.watch(bookApiProvider).autoTaskRepository,
);
final autoTaskServiceProvider = Provider<AutoTaskService>(
  (ref) => ref.watch(bookApiProvider).autoTaskService,
);
