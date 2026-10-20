import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

/// 普通诊断日志有界排队、合并写入；不承担崩溃最后落盘。— Codex + UI
class BoundedLogWriter {
  BoundedLogWriter(
    this.file, {
    this.maxFileBytes = 1024 * 1024,
    this.maxPendingBytes = 64 * 1024,
    this.onError,
  });
  final File file;
  final int maxFileBytes, maxPendingBytes;
  final void Function(Object, StackTrace)? onError;
  final _queue = Queue<List<int>>();
  int _pendingBytes = 0;
  int droppedLines = 0;
  bool _closed = false;
  Future<void>? _draining;

  void add(String line) {
    if (_closed) return;
    final bytes = utf8.encode(line);
    if (bytes.length > maxPendingBytes || bytes.length > maxFileBytes) {
      droppedLines++;
      return;
    }
    while (_pendingBytes + bytes.length > maxPendingBytes) {
      _pendingBytes -= _queue.removeFirst().length;
      droppedLines++;
    }
    _queue.add(bytes);
    _pendingBytes += bytes.length;
    _draining ??= Future<void>(_drain);
  }

  Future<void> _drain() async {
    try {
      while (_queue.isNotEmpty) {
        final batch = <int>[];
        while (_queue.isNotEmpty &&
            batch.length + _queue.first.length <= maxFileBytes) {
          final line = _queue.removeFirst();
          _pendingBytes -= line.length;
          batch.addAll(line);
        }
        try {
          final stat = await file.stat();
          final append =
              stat.type == FileSystemEntityType.file &&
              stat.size + batch.length <= maxFileBytes;
          await file.writeAsBytes(
            batch,
            mode: append ? FileMode.append : FileMode.write,
          );
        } catch (error, stack) {
          // 日志失败不能向业务路径抛错，也不能递归写同一日志。
          try {
            onError?.call(error, stack);
          } catch (_) {
            // 诊断回调本身失败时也不能制造未捕获异常。
          }
        }
      }
    } finally {
      _draining = null;
    }
  }

  Future<void> flush() async {
    while (_draining != null) {
      await _draining;
    }
  }

  Future<void> close() async {
    _closed = true;
    await flush();
  }
}
