import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/contracts/audio_book_service.dart';
import '../../../domain/contracts/bookshelf_repository.dart';
import '../../../models/book.dart';
import '../../../providers/audio/audio_state.dart';
import 'audio_preferences_host.dart';

/// 书级倍速防抖仍沿用原来的600ms窗口。
const Duration kSpeedPersistDebounce = Duration(milliseconds: 600);

/// 同一书级配置入口串行合并字段，书籍快照只由宿主持有。— Codex + UI
final class AudioBookPreferencesService {
  AudioBookPreferencesService({
    required this._host,
    required this._bookshelf,
    required this._audioBook,
  });

  final AudioPreferencesHost _host;
  final BookshelfRepository _bookshelf;
  final AudioBookService _audioBook;
  bool _released = false;
  bool get _disposed => _released || _host.isDisposed();
  Future<void> _writes = Future.value();
  Timer? _speedTimer;
  ({Book book, String url, double speed})? _pendingSpeed;

  Book? get boundBook => _host.readBook();
  String get currentBookUrl {
    final bound = boundBook?.bookUrl ?? '';
    return bound.isNotEmpty ? bound : _host.readState().bookUrl;
  }

  Future<void> bindBook(String url) async {
    if (_disposed || url.isEmpty || boundBook?.bookUrl == url) return;
    _host.writeBook(null);
    final token = _host.currentToken();
    try {
      final book = await _bookshelf.getBook(url);
      if (!_disposed && token == _host.currentToken()) _host.writeBook(book);
    } catch (error) {
      debugPrint('读取书级朗读引擎配置失败: $error');
    }
  }

  /// 每次执行时读取当前书或存储中的最新值，不让模式/倍速/引擎互相覆盖。
  Future<Book?> updateReadConfig(
    String url,
    FutureOr<ReadConfig> Function(ReadConfig) transform, {
    Book? fallback,
  }) {
    final operation = _writes.then((_) async {
      if (_disposed || url.isEmpty) return null;
      final current = boundBook;
      final book = current?.bookUrl == url
          ? current
          : await _bookshelf.getBook(url) ?? fallback;
      if (_disposed || book == null) return null;
      final config = await transform(book.readConfig ?? const ReadConfig());
      if (_disposed) return null;
      final updated = book.copyWith(readConfig: config);
      await _bookshelf.updateBook(updated);
      if (!_disposed && currentBookUrl == url) _host.writeBook(updated);
      return updated;
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> apply(Book? book, {String? fallbackBookUrl}) async {
    if (_disposed) return;
    final url = book != null && book.bookUrl.isNotEmpty
        ? book.bookUrl
        : ((fallbackBookUrl?.isNotEmpty ?? false)
              ? fallbackBookUrl!
              : _host.readState().bookUrl);
    if (url.isEmpty) return;
    final token = _host.currentToken();
    var target = book;
    if (target == null || target.readConfig == null) {
      try {
        target = await _bookshelf.getBook(url) ?? target;
      } catch (error) {
        debugPrint('读取书级听书配置失败: $error');
      }
    }
    if (_disposed || token != _host.currentToken()) return;
    if (target != null) _host.writeBook(target);
    final config = target?.readConfig;
    if (config == null) return;
    final mode =
        config.playMode <= 0 || config.playMode >= AudioPlayMode.values.length
        ? AudioPlayMode.sequential
        : AudioPlayMode.values[config.playMode];
    final state = _host.readState();
    if (mode != state.mode) _host.writeState(state.copyWith(mode: mode));
    final speed = config.playSpeed;
    if (speed >= 0.5 &&
        speed <= 3.0 &&
        (speed - _host.readState().config.speed).abs() > 0.001) {
      _host.updateConfig(speed: speed, persistBookSpeed: false);
    }
  }

  Future<void> persistMode(AudioPlayMode mode) async {
    if (_disposed) return;
    final url = currentBookUrl;
    try {
      await updateReadConfig(
        url,
        (config) => _audioBook.audioWithPlayMode(
          readConfig: config,
          playMode: mode.index,
        ),
      );
    } catch (error) {
      debugPrint('保存书级播放模式失败: $error');
    }
  }

  void scheduleSpeed(double speed) {
    if (_disposed) return;
    final book = boundBook;
    if (book == null) return;
    final url = book.bookUrl.isNotEmpty
        ? book.bookUrl
        : _host.readState().bookUrl;
    if (url.isEmpty) return;
    // 回到原值时也取消较早的待写倍率，不能稍后再写回旧滑块位置。
    _speedTimer?.cancel();
    _pendingSpeed = null;
    if (book.readConfig != null &&
        (book.readConfig!.playSpeed - speed).abs() < 0.001) {
      return;
    }
    _pendingSpeed = (book: book, url: url, speed: speed);
    _speedTimer = Timer(kSpeedPersistDebounce, () {
      final pending = _pendingSpeed;
      _pendingSpeed = null;
      if (pending != null) {
        unawaited(_persistSpeed(pending.book, pending.url, pending.speed));
      }
    });
  }

  Future<void> _persistSpeed(Book book, String url, double speed) async {
    try {
      await updateReadConfig(
        url,
        (config) => config.copyWith(playSpeed: speed),
        fallback: book,
      );
    } catch (error) {
      debugPrint('保存书级语速失败: $error');
    }
  }

  void dispose() {
    if (_released) return;
    _released = true;
    _speedTimer?.cancel();
    _pendingSpeed = null;
  }
}
