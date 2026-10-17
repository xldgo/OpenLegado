import '../../providers/domain_config_provider.dart';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/cloud_tts_repository.dart';
import '../../platform/tts/system_tts.dart';
import '../audio/application/audio_notifier.dart';
import 'cloud_tts_providers.dart';
import 'http_tts_repository_provider.dart';
import 'http_tts_voice_selection.dart';
import 'read_aloud_voice_provider.dart';
import 'tts_providers.dart';

/// 播放器展示快照不含 URL、凭据，不触发合成、保存或系统音色发现。— Codex + UI
class ReadAloudPlayerInfo {
  const ReadAloudPlayerInfo({
    this.engineName,
    this.voiceName,
    this.system = false,
  });
  final String? engineName, voiceName;
  final bool system;
}

final readAloudPlayerInfoProvider = FutureProvider.autoDispose((ref) async {
  // 选择后的重播/暂停会刷新展示；进度回调不重复读取配置。
  final audio = ref.watch(
    audioNotifierProvider.select(
      (state) => (state.bookUrl, state.config, state.state, state.isStreamMode),
    ),
  );
  if (audio.$4) return const ReadAloudPlayerInfo();
  final notifier = ref.read(audioNotifierProvider.notifier);
  final selection = notifier.resolveTtsEngineUrl();
  if (selection.isEmpty) return const ReadAloudPlayerInfo();
  final selectionsRepository = ref.read(readAloudSelectionRepositoryProvider);
  final catalog = ref.watch(readAloudVoicesProvider.future);
  if (selection == systemTtsEngineUrl) {
    final system = ref.read(systemTtsServiceProvider);
    final engineName = system.selectedEngine;
    final voiceKey = audio.$2.voiceName ?? system.selectedVoice;
    final voices = await catalog;
    final voice = voices
        .where(
          (v) =>
              v.engineType == 'system' &&
              v.engineId == 'system:$engineName' &&
              v.selectable &&
              v.traitsJson.startsWith('{') &&
              (jsonDecode(v.traitsJson) as Map)['voiceKey'] == voiceKey,
        )
        .firstOrNull;
    return ReadAloudPlayerInfo(
      system: true,
      engineName: engineName.isEmpty ? null : engineName,
      voiceName: voice?.displayName,
    );
  }
  if (isCloudTts(selection)) {
    final id = cloudTtsId(selection);
    final repository = ref.read(cloudTtsRepositoryProvider);
    final voices = await catalog;
    final engine = (await repository.list())
        .where((e) => e.id == id)
        .firstOrNull;
    if (engine == null) throw StateError('当前云端引擎已不存在');
    final selectedVoice = await selectionsRepository.getCloudVoice(id);
    final voice = voices
        .where(
          (v) =>
              v.engineType == 'cloud_tts' &&
              v.engineId == id &&
              v.id == selectedVoice &&
              v.selectable,
        )
        .firstOrNull;
    return ReadAloudPlayerInfo(
      engineName: engine.name,
      voiceName: voice?.displayName,
    );
  }
  final repository = ref.read(httpTtsRepositoryProvider);
  final id = await notifier.resolveTtsEngineId();
  final voices = await catalog;
  final engine = (await repository.getHttpTts())
      .where((e) => e.id == id)
      .firstOrNull;
  if (engine == null) throw StateError('当前 HTTP 引擎已不存在');
  final choice = await selectionsRepository.getHttpVoice(engine.id);
  final voice = resolveHttpTtsVoice(engine.id, voices, choice).voice;
  return ReadAloudPlayerInfo(
    engineName: engine.name,
    voiceName: voice?.displayName,
  );
});
