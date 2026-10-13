import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/http_tts_synthesizer.dart';
import '../../platform/tts/system_tts.dart';
import '../../platform/tts/system_tts_service.dart';
import '../../providers/providers.dart';

/// HTTP 合成共享根装配引用；独立覆盖不会触及配置或原生初始化。— Codex + UI
final httpTtsSynthesizerProvider = Provider<HttpTtsSynthesizer>(
  (ref) => ref.watch(bookApiProvider).httpTtsSynthesizer,
);

/// 系统插件按原播放会话持有，普通 HTTP 播放不初始化插件。
final systemTtsServiceProvider = Provider<SystemTts>(
  (ref) => SystemTtsService(),
);
