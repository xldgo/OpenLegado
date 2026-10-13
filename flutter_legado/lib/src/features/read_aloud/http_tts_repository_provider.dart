import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/http_tts_repository.dart';
import '../../providers/providers.dart';

/// 配置页、引擎选择与导入共用应用装配的唯一实例。— Codex + UI
final httpTtsRepositoryProvider = Provider<HttpTtsRepository>(
  (ref) => ref.watch(bookApiProvider).httpTtsRepository,
);
