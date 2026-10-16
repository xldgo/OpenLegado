import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/source_switch_service.dart';
import '../providers.dart';

/// 共享应用装配实例，也支持消费者独立替换。— Codex + UI
final sourceSwitchServiceProvider = Provider<SourceSwitchService>(
  (ref) => ref.watch(bookApiProvider).sourceSwitchService,
);
