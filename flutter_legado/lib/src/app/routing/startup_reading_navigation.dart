import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book.dart';
import '../../features/book_detail/book_detail_notifier.dart';
import '../../services/crash_log_service.dart';
import '../../utils/book_open_utils.dart';
import 'app_navigation.dart';
import 'route_names.dart';

/// 启动恢复归应用作用域，欢迎页只交接书籍，不在退场后继续持有Ref。— Codex + UI
final startupReadingNavigationProvider = Provider<StartupReadingNavigation>((
  ref,
) {
  late final StartupReadingNavigation navigation;
  navigation = StartupReadingNavigation(
    open: (book, isCurrent) async {
      final nav = navigation.navigator;
      if (nav == null) return;
      final router = GoRouter.of(nav.context);
      final prepared = await ref
          .read(bookDetailServiceProvider)
          .resolveReading(book);
      if (!isCurrent()) return;
      final route = BookOpenUtils.routeForTypeBits(prepared.typeBits);
      // 文本会话由ReaderRouteEntry在书籍门禁通过后激活。
      unawaited(
        router.pushAppRoute(
          route,
          extra: route == AppRoutes.reader
              ? prepared.book
              : BookOpenUtils.argumentsForRoute(route, prepared.book),
        ),
      );
    },
    onError: (error, stack) =>
        CrashLogService.instance.put('恢复上次阅读失败：$error', error: error),
  );
  ref.onDispose(navigation.dispose);
  return navigation;
});

/// 只有主页真正进入栈后才恢复；明确的外部动作或离场使旧任务失效。
class StartupReadingNavigation extends NavigatorObserver {
  StartupReadingNavigation({required this.open, required this.onError});
  final Future<void> Function(Book, bool Function()) open;
  final void Function(Object, StackTrace) onError;
  Book? _pending;
  bool _home = false, _external = false, _scheduled = false, _closed = false;
  int _generation = 0;

  void request(Book book) {
    if (_closed || _external) return;
    _pending = book;
    _schedule();
  }

  void preferExternalAction() {
    _external = true;
    _pending = null;
    _generation++;
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _home = topRoute.settings.name == AppRoutes.home;
    if (!_home) {
      preferExternalAction();
    }
    _schedule();
  }

  void _schedule() {
    if (_closed || !_home || _pending == null || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_closed || !_home || _external || _pending == null) return;
      final book = _pending!;
      _pending = null;
      final generation = ++_generation;
      bool current() =>
          !_closed &&
          !_external &&
          _home &&
          generation == _generation &&
          navigator?.mounted == true;
      unawaited(
        Future<void>.sync(() => open(book, current))
            .catchError((Object error, StackTrace stack) {
              if (current()) onError(error, stack);
            }),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void dispose() {
    _closed = true;
    _pending = null;
    _generation++;
  }
}
