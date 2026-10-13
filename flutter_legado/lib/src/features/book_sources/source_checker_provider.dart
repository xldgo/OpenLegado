import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/source_checker.dart';
import '../../providers/providers.dart';

/// 根替换后提供新的校验能力；正在执行的会话自行持有发起实例。— Codex + UI
final sourceCheckerProvider = Provider<SourceChecker>(
  (ref) => ref.watch(bookApiProvider).sourceChecker,
);
