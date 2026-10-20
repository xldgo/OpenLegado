import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contracts/reader_font_repository.dart';
import '../../domain/models/reader_font.dart';
import '../../services/settings_write_queue.dart';

/// 保持原StringList格式；集合操作串行，保存成功后发布目录。— Codex + UI
final class AppReaderFontRepository implements ReaderFontRepository {
  AppReaderFontRepository({
    Future<List<String>> Function()? read,
    Future<void> Function(List<String>)? write,
  }) : _read = read ?? _readPreferences,
       _write = write ?? _writePreferences;

  static const _key = 'reader_custom_fonts';
  final Future<List<String>> Function() _read;
  final Future<void> Function(List<String>) _write;
  final _queue = SettingsWriteQueue();
  final _changes = StreamController<List<ReaderFont>>.broadcast();
  List<ReaderFont> _current = const [];
  bool _loaded = false;

  static Future<List<String>> _readPreferences() async =>
      (await SharedPreferences.getInstance()).getStringList(_key) ?? [];

  static Future<void> _writePreferences(List<String> raw) async {
    if (!await (await SharedPreferences.getInstance()).setStringList(
      _key,
      raw,
    )) {
      throw StateError('自定义字体目录保存失败');
    }
  }

  @override
  List<ReaderFont> get current => _current;

  @override
  Stream<List<ReaderFont>> watch() => Stream.multi((listener) {
    final subscription = _changes.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.add(_current);
    listener.onCancel = subscription.cancel;
  });

  void _publish(List<String> raw) {
    final fonts = raw.map(ReaderFont.decode).whereType<ReaderFont>().toList();
    _loaded = true;
    if (fonts.length == _current.length &&
        fonts.indexed.every((entry) => entry.$2 == _current[entry.$1])) {
      return;
    }
    _current = List.unmodifiable(fonts);
    _changes.add(_current);
  }

  @override
  Future<List<ReaderFont>> load() async {
    await _queue.run(() async {
      if (!_loaded) _publish(await _read());
    });
    return current;
  }

  @override
  Future<void> reload() => _queue.run(() async => _publish(await _read()));

  @override
  Future<void> add(ReaderFont font) => _queue.run(() async {
    final raw = List<String>.of(await _read());
    final index = raw.indexWhere(
      (entry) => ReaderFont.decode(entry)?.family == font.family,
    );
    if (index < 0) {
      raw.add(font.encode());
    } else {
      raw.removeWhere(
        (entry) => ReaderFont.decode(entry)?.family == font.family,
      );
      raw.insert(index, font.encode());
    }
    await _write(List.unmodifiable(raw));
    _publish(raw);
  });

  Future<void> dispose() async {
    await _queue.run(() async {});
    await _changes.close();
  }
}
