import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../platform/tts/system_tts.dart';
import 'tts_providers.dart';

List<SystemVoiceCatalogEntry> systemVoiceEntries(List<SystemTtsVoice> voices) {
  final sorted = List<SystemTtsVoice>.of(voices)
    ..sort((a, b) {
      final locale = a.locale.compareTo(b.locale);
      return locale != 0 ? locale : a.name.compareTo(b.name);
    });
  final ids = <String>{};
  return [
    for (final v in sorted)
      if (ids.add(v.identifier?.isNotEmpty == true ? v.identifier! : v.name))
        SystemVoiceCatalogEntry(
          speakerId: v.identifier?.isNotEmpty == true ? v.identifier! : v.name,
          displayName: v.name,
          traitsJson: jsonEncode({
            'locale': v.locale,
            'networkRequired': v.networkRequired,
            'voiceKey': v.key,
          }),
        ),
  ];
}

final readAloudVoicesProvider =
    AsyncNotifierProvider<ReadAloudVoicesNotifier, List<ReadAloudVoice>>(
      ReadAloudVoicesNotifier.new,
    );

class ReadAloudVoicesNotifier extends AsyncNotifier<List<ReadAloudVoice>> {
  @override
  Future<List<ReadAloudVoice>> build() =>
      ref.watch(readAloudVoiceRepositoryProvider).list();
  Future<void> reload() async {
    state = const AsyncLoading();
    final repository = ref.read(readAloudVoiceRepositoryProvider);
    final result = await AsyncValue.guard(repository.list);
    if (ref.mounted) state = result;
  }

  Future<void> discoverSystem(SystemTts system) async {
    final voices = await system.getVoices();
    if (!ref.mounted) return;
    await ref
        .read(readAloudVoiceRepositoryProvider)
        .syncSystem(
          'system:${system.selectedEngine}',
          systemVoiceEntries(voices),
        );
    if (ref.mounted) await reload();
  }

  Future<void> setFlags(
    ReadAloudVoice voice, {
    bool? enabled,
    bool? excluded,
  }) async {
    await ref
        .read(readAloudVoiceRepositoryProvider)
        .setFlags(
          voice.id,
          enabled: enabled ?? voice.enabled,
          excluded: excluded ?? voice.excluded,
        );
    if (ref.mounted) await reload();
  }
}
