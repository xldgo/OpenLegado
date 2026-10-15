import 'dart:math' as math;

/// 与上游正文媒体时间轴一致：每秒4个UTF-16字符乘实际朗读倍率。— Codex + UI
int readAloudMediaTime(int offset, double speed) =>
    offset <= 0 || !speed.isFinite || speed <= 0
    ? 0
    : (offset * 1000 / (4 * speed)).floor();

int readAloudMediaOffset(int milliseconds, int length, double speed) =>
    length <= 0 || !speed.isFinite || speed <= 0
    ? 0
    : (math.max(0, milliseconds) * 4 * speed / 1000).floor().clamp(
        0,
        length - 1,
      );

/// 复用上游单调推进/暂停冻结规则；主动定位、章节或倍率变化由调用方重置。
final class ReadAloudMediaClock {
  int? _position;
  int _updatedAt = 0;
  bool _playing = false;

  int update({
    required int estimate,
    required int duration,
    required bool playing,
    required int now,
  }) {
    final previous = _position;
    final delta = math.max(0, now - _updatedAt);
    final position = previous == null
        ? estimate
        : !playing
        ? (_playing ? previous + delta : previous)
        : !_playing
        ? previous
        : math.max(estimate, previous + delta);
    _playing = playing;
    _updatedAt = now;
    return _position = position.clamp(0, math.max(0, duration));
  }
}
