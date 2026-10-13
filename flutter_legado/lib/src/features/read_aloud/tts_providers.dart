import 'dart:convert';

import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../domain/contracts/tts_cache_repository.dart';

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
  (ref) => SystemTtsService(
    excludedVoiceKeys: (engine) async {
      if (!ref.mounted) return {};
      final repo = ref.read(readAloudVoiceRepositoryProvider);
      if (!repo.supportsCatalog) return {};
      final voices = await repo.list();
      return {
        for (final v in voices)
          if (v.engineType == 'system' &&
              v.engineId == 'system:$engine' &&
              (!v.enabled || v.excluded))
            (jsonDecode(v.traitsJson) as Map<String, dynamic>)['voiceKey']
                as String,
      };
    },
  ),
);

/// 缓存与 HTTP 合成分开注入，沿用根装配的一份权威目录。
final ttsCacheRepositoryProvider = Provider<TtsCacheRepository>(
  (ref) => ref.watch(bookApiProvider).ttsCacheRepository,
);

final readAloudVoiceRepositoryProvider = Provider<ReadAloudVoiceRepository>(
  (ref) => ref.watch(bookApiProvider).readAloudVoiceRepository,
);
