import '../../../models/book.dart';
import '../../../providers/audio/audio_state.dart';

/// 偏好操作读取宿主唯一快照，不接收Ref或Notifier。— Codex + UI
final class AudioPreferencesHost {
  const AudioPreferencesHost({
    required this.readState,
    required this.writeState,
    required this.readBook,
    required this.writeBook,
    required this.currentToken,
    required this.isDisposed,
    required this.updateConfig,
    required this.restartReadAloud,
  });

  final AudioState Function() readState;
  final void Function(AudioState) writeState;
  final Book? Function() readBook;
  final void Function(Book?) writeBook;
  final int Function() currentToken;
  final bool Function() isDisposed;
  final void Function({
    String? engineUrl,
    int? engineId,
    double? speed,
    bool restartPlayback,
    bool persistBookSpeed,
  })
  updateConfig;
  final Future<void> Function() restartReadAloud;
}
