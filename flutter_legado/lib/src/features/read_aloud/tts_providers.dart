import '../../app/bootstrap/application_dependencies.dart'
    show readAloudVoiceRepositoryProvider;
export '../../app/bootstrap/application_dependencies.dart'
    show
        httpTtsSynthesizerProvider,
        ttsCacheRepositoryProvider,
        readAloudVoiceRepositoryProvider;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/tts/system_tts.dart';
import '../../platform/tts/system_tts_service.dart';

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
