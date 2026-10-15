import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../models/book.dart';
import '../../services/audio_service.dart';
import '../../services/media_session_models.dart';
import '../../routes.dart';

final class MediaPlaybackDestination {
  const MediaPlaybackDestination(this.route, {this.book});
  final String route;
  final Book? book;
}

/// 导航只消费有效会话，不创建播放；欢迎页未退出时保留最新点击。— Codex + UI
class MediaPlaybackNavigation extends NavigatorObserver {
  MediaPlaybackNavigation({required this.resolve});
  final MediaPlaybackDestination? Function(MediaPlaybackTarget) resolve;
  final _routes = <Route<dynamic>>[];
  StreamSubscription<MediaPlaybackTarget>? _subscription;
  MediaPlaybackTarget? _pending;
  bool _closed = false, _scheduled = false;

  void attach(AudioService service) {
    _subscription = service.openPlaybackStream.listen(open);
    unawaited(() async {
      final initial = await service.takePendingOpen();
      if (!_closed && initial != null) open(initial);
    }());
  }

  void open(MediaPlaybackTarget target) {
    if (_closed) return;
    _pending = target;
    _schedule();
  }

  void _schedule() {
    if (_closed || _pending == null || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_closed ||
          _pending == null ||
          navigator == null ||
          _routes.isEmpty ||
          _routes.any((route) => route.settings.name == AppRoutes.welcome)) {
        return;
      }
      final request = _pending!;
      _pending = null;
      final destination = resolve(request);
      if (destination == null) return;
      final existing = _routes.where((route) {
        if (route.settings.name != destination.route) return false;
        if (destination.route != AppRoutes.audio) return true;
        final arguments = route.settings.arguments;
        return arguments is Book &&
            arguments.bookUrl == destination.book?.bookUrl;
      }).lastOrNull;
      if (existing != null) {
        navigator!.popUntil((route) => identical(route, existing));
      } else {
        unawaited(
          navigator!.pushNamed(destination.route, arguments: destination.book),
        );
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) _routes.clear();
    _routes.add(route);
    _schedule();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _schedule();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _schedule();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _schedule();
  }

  void dispose() {
    _closed = true;
    _pending = null;
    unawaited(_subscription?.cancel());
  }
}
