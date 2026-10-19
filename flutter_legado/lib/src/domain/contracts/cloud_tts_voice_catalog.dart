import 'cloud_tts_repository.dart';
import 'http_tts_synthesizer.dart';

/// 服务商返回的候选音色；目录不等于用户已保存音色。— Codex + Bridge
final class CloudTtsVoiceDescriptor {
  const CloudTtsVoiceDescriptor({
    required this.id,
    required this.name,
    this.locale = '',
    this.gender = '',
    this.styles = const [],
    this.roles = const [],
    this.sampleRate,
  });
  final String id, name, locale, gender;
  final List<String> styles, roles;
  final int? sampleRate;
}

abstract interface class CloudTtsVoiceCatalog {
  Future<List<CloudTtsVoiceDescriptor>> discover(
    CloudTtsEngine engine,
    HttpTtsCancellation cancellation,
  );
}
