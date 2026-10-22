/// Rust计算的音频跳过窗口，Flutter只负责应用seek和章末动作。— Codex + Bridge
final class AudioSkipWindow {
  const AudioSkipWindow({required this.introEndMs, required this.outroStartMs});
  final int introEndMs;
  final int outroStartMs;
}
