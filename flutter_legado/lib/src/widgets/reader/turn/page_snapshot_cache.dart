import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'page_snapshot.dart';

/// One set of page bitmaps for horizontal turn painting.
class PageSnapshotTriple {
  PageSnapshotTriple({this.prev, this.cur, this.next});

  ui.Image? prev;
  ui.Image? cur;
  ui.Image? next;

  void dispose() {
    prev?.dispose();
    cur?.dispose();
    next?.dispose();
    prev = null;
    cur = null;
    next = null;
  }
}

typedef SnapshotCapturer = Future<ui.Image?> Function(
  GlobalKey key, {
  double? pixelRatio,
});

/// Double-buffered prev/cur/next snapshots (Jingshiro setBitmap timing).
class PageSnapshotCache {
  PageSnapshotCache({SnapshotCapturer? capturer})
    : _capturer = capturer ?? captureBoundary;

  final SnapshotCapturer _capturer;
  PageSnapshotTriple? _display;
  Future<bool>? _refreshing;
  int? _refreshGeneration;
  int _generation = 0;

  PageSnapshotTriple? get display => _display;

  bool get hasCur => _display?.cur != null;

  /// Capture into a pending triple; swap only when required images succeed.
  /// On failure, keeps the previous [display] intact and returns false.
  Future<bool> refresh({
    required GlobalKey prevKey,
    required GlobalKey curKey,
    required GlobalKey nextKey,
    required double pixelRatio,
    required bool hasPrev,
    required bool hasNext,
  }) async {
    final generation = _generation;
    // 同页请求共用在途抓取；换页后的请求等旧抓取结束再生成当前页快照。
    while (_refreshing != null) {
      final refreshingGeneration = _refreshGeneration;
      final ok = await _refreshing!;
      if (generation != _generation) return false;
      if (refreshingGeneration == generation) return ok;
    }
    if (generation != _generation) return false;

    Future<bool> capture() async {
      final cur = await _capturer(curKey, pixelRatio: pixelRatio);
      if (cur == null) {
        return false;
      }

      ui.Image? prev;
      if (hasPrev) {
        prev = await _capturer(prevKey, pixelRatio: pixelRatio);
        if (prev == null) {
          cur.dispose();
          return false;
        }
      }

      ui.Image? next;
      if (hasNext) {
        next = await _capturer(nextKey, pixelRatio: pixelRatio);
        if (next == null) {
          cur.dispose();
          prev?.dispose();
          return false;
        }
      }

      final pending = PageSnapshotTriple(prev: prev, cur: cur, next: next);
      if (generation != _generation) {
        pending.dispose();
        return false;
      }
      final old = _display;
      _display = pending;
      old?.dispose();
      return true;
    }

    final refreshing = capture();
    _refreshing = refreshing;
    _refreshGeneration = generation;
    try {
      return await refreshing;
    } finally {
      if (identical(_refreshing, refreshing)) {
        _refreshing = null;
        _refreshGeneration = null;
      }
    }
  }

  void invalidate() {
    _generation++;
    _display?.dispose();
    _display = null;
  }
}
