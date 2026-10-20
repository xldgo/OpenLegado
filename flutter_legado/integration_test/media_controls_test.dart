import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_legado/src/features/read_aloud/media_playback_navigation.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/services/audio_service.dart';
import 'package:flutter_legado/src/services/media_session_models.dart';

/// 隔离Android设备专用：宿主操作真正的系统面板，禁止在MuMu运行。
/// 必须 --no-uninstall；HTTP仅用于QA握手，不进入产品入口。— Codex + Bridge
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('系统进度、拖动、媒体按钮与通知导航真实接线', (tester) async {
    final service = AudioService.instance;
    var opens = 0, playerBuilds = 0, position = 10000, duration = 60000;
    final seeks = <int>[], buttons = <String>[];
    final finished = Completer<void>();
    final navigation = MediaPlaybackNavigation(
      resolve: (target) {
        if (target.mediaId != 'controls-fixture' || target.sessionToken != 71) {
          return null;
        }
        opens++;
        return const MediaPlaybackDestination(AppRoutes.readAloudPlayer);
      },
    );
    navigation.attach(service);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [navigation],
        home: const Scaffold(body: Center(child: Text('系统媒体验证首页'))),
        onGenerateRoute: (settings) {
          playerBuilds++;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                const Scaffold(body: Center(child: Text('通知返回播放页面'))),
          );
        },
      ),
    );
    await tester.runAsync(() async {
      Future<void> publish() => service.updateProgress(
        MediaPlaybackProgress(
          mediaId: 'controls-fixture',
          sessionToken: 71,
          chapterIndex: 2,
          state: 'paused',
          position: position,
          duration: duration,
          speed: 1,
          canSeek: duration > 0,
          hasPrevious: true,
          hasNext: true,
          isStream: true,
        ),
      );
      final seek = service.seekStream.listen((request) {
        seeks.add(request.position);
        position = request.position;
        unawaited(publish());
      });
      final button = service.mediaButtonStream.listen((event) {
        buttons.add(event.name);
      });
      HttpServer? server;
      await service.init();
      try {
        expect(service.isInitialized, isTrue);
        await service.updateMetadata(
          mediaId: 'controls-fixture',
          sessionToken: 71,
          title: '系统进度验证书',
          artist: '第三章',
          album: '系统进度验证书',
        );
        await service.notifyPaused();
        await publish();
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 18761);
        server.listen((request) async {
          switch (request.uri.path) {
            case '/finish':
              finished.complete();
            case '/unknown':
              duration = 0;
              position = 0;
              await publish();
            case '/restore':
              duration = 60000;
              position = 15000;
              await publish();
            case '/stale':
              await service.updateProgress(
                const MediaPlaybackProgress(
                  mediaId: 'controls-fixture',
                  sessionToken: 70,
                  chapterIndex: 1,
                  state: 'playing',
                  position: 1,
                  duration: 999000,
                  speed: 2,
                  canSeek: true,
                  hasPrevious: false,
                  hasNext: false,
                  isStream: true,
                ),
              );
          }
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'position': position,
              'duration': duration,
              'seeks': seeks,
              'buttons': buttons,
              'opens': opens,
              'playerBuilds': playerBuilds,
            }),
          );
          await request.response.close();
        });
        debugPrint('MEDIA_CONTROLS_QA:ready');
        final deadline = DateTime.now().add(const Duration(minutes: 4));
        while (!finished.isCompleted && DateTime.now().isBefore(deadline)) {
          // IntegrationTest默认按pump推进帧；真实应用由引擎自动调度。
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(finished.isCompleted, isTrue, reason: '宿主未在4分钟内完成系统操作');
        expect(seeks, isNotEmpty, reason: '宿主必须实际拖动系统进度条');
        expect(buttons, containsAll(['skipToNext', 'skipToPrevious']));
        expect(opens, greaterThanOrEqualTo(2), reason: '宿主点击通知两次');
        expect(playerBuilds, 1, reason: '重复通知点击不创建新播放页面');
      } finally {
        await server?.close(force: true);
        await seek.cancel();
        await button.cancel();
        navigation.dispose();
        await service.notifyStopped();
        await service.dispose();
      }
    });
  });
}
