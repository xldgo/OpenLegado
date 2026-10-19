import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book.dart';
import '../../features/book_detail/book_detail_notifier.dart';
import '../../services/crash_log_service.dart';
import '../../utils/book_open_utils.dart';
import '../../widgets/crash_log_dialog.dart';
import 'app_navigation.dart';
import 'route_names.dart';

/// 启动恢复归应用作用域，外部入口判定完成后才准备书籍。— Codex + UI
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
  bool _initialActionsReady = true, _opening = false;
  int _generation = 0;

  /// 初始深链、媒体通知及悬浮窗回传均完成判定后，才允许默认开读。
  void waitForInitialActions(Future<void> ready) {
    _initialActionsReady = false;
    unawaited(
      ready.then(
        (_) {
          if (_closed) return;
          _initialActionsReady = true;
          _schedule();
        },
        onError: (Object error, StackTrace stack) {
          if (_closed) return;
          preferExternalAction();
          onError(error, stack);
        },
      ),
    );
  }

  void request(Book book) {
    if (_closed || _external) return;
    _generation++;
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
    // 自动显示的崩溃提示只暂停恢复，不代表用户选择了其他目的地。
    if (!_home && topRoute.settings.name != CrashLogDialog.routeName) {
      preferExternalAction();
    }
    _schedule();
  }

  void _schedule() {
    if (_closed ||
        _external ||
        !_initialActionsReady ||
        !_home ||
        _pending == null ||
        _scheduled ||
        _opening) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_closed ||
          !_home ||
          _external ||
          !_initialActionsReady ||
          _pending == null ||
          _opening) {
        return;
      }
      final book = _pending!;
      _opening = true;
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
            })
            .whenComplete(() {
              // 弹窗覆盖准备过程时保留请求，关闭后可重新准备；新请求不被旧结果清除。
              if (current()) _pending = null;
              _opening = false;
              _schedule();
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
