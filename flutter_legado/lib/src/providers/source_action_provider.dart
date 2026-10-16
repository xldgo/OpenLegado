import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/source_action_service.dart';
import 'providers.dart';

/// 动作服务负责原生执行和平台回放，页面只决定剩余默认操作。— Codex + UI
final sourceActionServiceProvider = Provider<SourceActionService>(
  (ref) => ref.watch(bookApiProvider).sourceActionService,
);
