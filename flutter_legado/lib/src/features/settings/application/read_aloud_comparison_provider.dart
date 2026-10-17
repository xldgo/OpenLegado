import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/read_aloud_comparison_samples.dart';
import '../../../services/audio_service.dart';
import '../../../services/read_aloud_audio_player.dart';
import '../../../services/read_aloud_comparison.dart';
import '../../../services/read_aloud_diagnostics.dart';
import '../../audio/application/audio_notifier.dart';
import '../../read_aloud/tts_providers.dart';

/// 复用正式音频焦点，但不把诊断音频加入书籍或媒体进度。— Codex + UI
final readAloudComparisonProvider = Provider.autoDispose<ReadAloudComparison>((
  ref,
) {
  final samples = ReadAloudComparisonSamples(
    repository: ref.read(ttsCacheRepositoryProvider),
  );
  final media = ref.read(audioServiceProvider);
  final mainPlayer = ref.read(audioNotifierProvider.notifier);
  final diagnostics = ReadAloudDiagnostics.instance;
  final previousSnapshot = diagnostics.markSnapshot;
  final player = ReadAloudAudioPlayer();
  final comparisonSnapshot = diagnostics.markSnapshot;
  final comparison = ReadAloudComparison(
    player: player,
    loadFixture: samples.prepare,
    saveReport: samples.saveReport,
    closeSamples: samples.close,
    beforeRun: () async {
      await mainPlayer.stopForComparison();
      await media.notifyStopped();
      await media.abandonAudioFocus();
      await media.init();
      if (!await media.requestAudioFocus()) throw StateError('无法取得音频焦点');
      // 真实音频接管保活，避免 Web 服务的静音音轨与对照同时播放。
      await media.notifyPlaying();
    },
    afterRun: () async {
      await media.notifyStopped();
      await media.abandonAudioFocus();
    },
  );
  final focus = media.audioFocusStream.listen((event) {
    if (event != AudioFocusEvent.gain && comparison.running) {
      unawaited(comparison.stop(reason: 'focus_loss'));
    }
  });
  final buttons = media.mediaButtonStream.listen((_) {
    if (comparison.running) unawaited(comparison.stop(reason: 'media_button'));
  });
  ref.listen(audioNotifierProvider, (_, next) {
    if (comparison.running &&
        (next.isPlaying || next.state == PlayerState.loading)) {
      unawaited(comparison.stop(reason: 'other_playback'));
    }
  });
  ref.onDispose(() {
    unawaited(focus.cancel());
    unawaited(buttons.cancel());
    unawaited(() async {
      try {
        await comparison.close();
      } catch (_) {
        debugPrint('关闭朗读对照失败，保留未释放的样本');
      } finally {
        if (diagnostics.markSnapshot == null ||
            identical(diagnostics.markSnapshot, comparisonSnapshot)) {
          diagnostics.markSnapshot = previousSnapshot;
        }
      }
    }());
  });
  return comparison;
});
