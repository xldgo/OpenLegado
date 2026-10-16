import '../../app/bootstrap/application_dependencies.dart'
    show cloudTtsRepositoryProvider;
export '../../app/bootstrap/application_dependencies.dart'
    show cloudTtsRepositoryProvider;
import '../../services/stream_audio_player.dart';
import '../../services/read_aloud_audio_player.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contracts/cloud_tts_credential_store.dart';
import '../../domain/contracts/cloud_tts_synthesizer.dart';
import '../../domain/contracts/http_tts_synthesizer.dart';
import '../../data/services/rust_cloud_tts_synthesizer.dart';
import '../../data/repositories/mock_cloud_tts_repository.dart';
import '../../platform/tts/cloud_tts_credential_store.dart';
import 'cloud_tts_settings.dart';

final cloudTtsCredentialStoreProvider = Provider<CloudTtsCredentialStore>(
  (ref) => ref.watch(cloudTtsRepositoryProvider) is MockCloudTtsRepository
      ? MemoryCloudTtsCredentialStore()
      : SecureCloudTtsCredentialStore(),
);
final cloudTtsSettingsProvider = Provider<CloudTtsSettings>(
  (ref) => CloudTtsSettings(
    ref.watch(cloudTtsRepositoryProvider),
    ref.watch(cloudTtsCredentialStoreProvider),
  ),
);
final cloudTtsSynthesizerProvider = Provider<CloudTtsSynthesizer>(
  (ref) => ref.watch(cloudTtsRepositoryProvider) is MockCloudTtsRepository
      ? _MockSynthesizer()
      : RustCloudTtsSynthesizer(
          ref.watch(cloudTtsRepositoryProvider),
          ref.watch(cloudTtsCredentialStoreProvider),
        ),
);

class _MockSynthesizer implements CloudTtsSynthesizer {
  @override
  Future<HttpTtsSynthesisResult> synthesize({
    required String engineId,
    required String text,
    String? voiceId,
    Map<String, dynamic>? voiceOptions,
    HttpTtsCancellation? cancellation,
  }) async => const HttpTtsNoAudio(HttpTtsNoAudioReason.mock);
}

/// 试听有独立播放器，不能接管正文的完成标签。
final cloudTtsPreviewPlayerProvider = Provider.autoDispose<StreamAudioPlayer>(
  (ref) => ReadAloudAudioPlayer(),
);
