import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/reader/turn/page_snapshot_cache.dart';

void main() {
  for (final invalidate in [false, true]) {
    testWidgets('在途快照${invalidate ? '失效后重新抓取当前页' : '供同页请求共用'}', (tester) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
          .drawRect(const ui.Rect.fromLTWH(0, 0, 8, 8), ui.Paint());
      final picture = recorder.endRecording();
      final firstImage = (await tester.runAsync(() => picture.toImage(8, 8)))!;
      final secondImage = firstImage.clone();
      picture.dispose();
      final pending = Completer<ui.Image?>();
      var captures = 0;
      final cache = PageSnapshotCache(
        capturer: (_, {pixelRatio}) {
          captures++;
          return captures == 1 ? pending.future : Future.value(secondImage);
        },
      );
      Future<bool> refresh() => cache.refresh(
        prevKey: GlobalKey(),
        curKey: GlobalKey(),
        nextKey: GlobalKey(),
        pixelRatio: 1,
        hasPrev: false,
        hasNext: false,
      );
      final first = refresh();
      if (invalidate) cache.invalidate();
      final second = refresh();
      pending.complete(firstImage);
      expect(await first, !invalidate);
      expect(await second, isTrue);
      expect(captures, invalidate ? 2 : 1);
      expect(cache.hasCur, isTrue);
      cache.invalidate();
      if (!invalidate) secondImage.dispose();
    });
  }

  testWidgets('重排后在途旧快照不能回填为新的可用翻页缓存', (tester) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
        .drawRect(const ui.Rect.fromLTWH(0, 0, 8, 8), ui.Paint());
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(8, 8));
    picture.dispose();
    final pending = Completer<ui.Image?>();
    final cache = PageSnapshotCache(
      capturer: (_, {pixelRatio}) => pending.future,
    );
    final refreshing = cache.refresh(
      prevKey: GlobalKey(),
      curKey: GlobalKey(),
      nextKey: GlobalKey(),
      pixelRatio: 1,
      hasPrev: false,
      hasNext: false,
    );
    cache.invalidate();
    pending.complete(image);
    expect(await refreshing, isFalse);
    expect(cache.hasCur, isFalse);
    expect(cache.display, isNull);
    cache.invalidate();
  });
}
