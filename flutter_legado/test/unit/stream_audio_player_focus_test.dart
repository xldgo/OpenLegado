import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/screens/video_screen.dart';

// 纯音频已迁至 just_audio，控制回归见 read_aloud_audio_player_test.dart，
// 媒体焦点唯一所有者回归见 audio_focus_wiring_test.dart。视频配置保持原样。
void main() {
  test('视频页保持其独立焦点和前后台策略', () {
    expect(videoPlaybackOptions.mixWithOthers, isFalse);
    expect(videoPlaybackOptions.allowBackgroundPlayback, isFalse);
  });
}
