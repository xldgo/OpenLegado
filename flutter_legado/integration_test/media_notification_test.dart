import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_legado/src/services/audio_service.dart';

/// 仅在隔离Android设备执行；宿主在各标记阶段读取dumpsys和通知截图。
/// 必须显式 --no-uninstall，禁止使用MuMu用户验收实例。— Codex + Bridge
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final service = AudioService.instance;

  Future<void> stage(String name) async {
    // 留出宿主读取原生状态的窗口，不以Dart通道调用成功代替原生验收。
    debugPrint('MEDIA_ARTWORK_QA:$name');
    await Future<void>.delayed(const Duration(seconds: 6));
  }

  testWidgets('真实媒体通知封面与文字更新生命周期', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text('媒体通知测试')),
      ),
    );
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
          .drawColor(const ui.Color(0xFFCC3344), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(96, 144);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      await service.init();
      expect(service.isInitialized, isTrue);
      try {
        await service.updateMetadata(
          mediaId: 'fixture-a',
          sessionToken: 1,
          title: '封面测试书',
          artist: '第一章',
          album: '封面测试书',
        );
        await service.notifyPlaying();
        await service.updateArtwork(
          mediaId: 'fixture-a',
          sessionToken: 1,
          artworkBytes: bytes,
        );
        await stage('visible');
        await service.updateMetadata(
          mediaId: 'fixture-a',
          sessionToken: 1,
          title: '封面测试书',
          artist: '第二章',
          album: '封面测试书',
          timerText: '剩余 4 章',
        );
        await service.notifyPaused();
        await stage('text-preserves-art');
        await service.updateMetadata(
          mediaId: 'fixture-b',
          sessionToken: 2,
          title: '另一本书',
          artist: '新章节',
          album: '另一本书',
        );
        await service.updateArtwork(
          mediaId: 'fixture-a',
          sessionToken: 1,
          artworkBytes: bytes,
        );
        await stage('switch-rejects-old');
        await service.updateArtwork(
          mediaId: 'fixture-b',
          sessionToken: 2,
          artworkBytes: bytes,
        );
        await service.updateArtwork(
          mediaId: 'fixture-b',
          sessionToken: 2,
          artworkBytes: null,
        );
        await stage('explicit-clear');
        await service.updateArtwork(
          mediaId: 'fixture-b',
          sessionToken: 2,
          artworkBytes: bytes,
        );
        await service.notifyStopped();
        await service.updateArtwork(
          mediaId: 'fixture-b',
          sessionToken: 2,
          artworkBytes: bytes,
        );
        await stage('stop-rejects-old');
      } finally {
        await service.notifyStopped();
        await service.dispose();
      }
    });
  });
}
