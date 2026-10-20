import '../../app/routing/app_navigation.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../models/book.dart';
import '../../services/audio_service.dart';
import '../../services/media_session_models.dart';
import '../../app/routing/route_names.dart';

final class MediaPlaybackDestination {
  const MediaPlaybackDestination(this.route, {this.book});
  final String route;
  final Book? book;
}

/// 导航只消费有效会话，不创建播放；Navigator 就绪后消费最新点击。— Codex + UI
class MediaPlaybackNavigation extends NavigatorObserver {
  MediaPlaybackNavigation({required this.resolve, this.onOpenRequested});
  final VoidCallback? onOpenRequested;
  final MediaPlaybackDestination? Function(MediaPlaybackTarget) resolve;
  final _routes = <Route<dynamic>>[];
  StreamSubscription<MediaPlaybackTarget>? _subscription;
  MediaPlaybackTarget? _pending;
  bool _closed = false, _scheduled = false;

  Future<void> attach(AudioService service) async {
    _subscription = service.openPlaybackStream.listen(open);
    final initial = await service.takePendingOpen();
    if (!_closed && initial != null) open(initial);
  }

  void open(MediaPlaybackTarget target) {
    if (_closed) return;
    onOpenRequested?.call();
    _pending = target;
    _schedule();
  }

  void _schedule() {
    if (_closed || _pending == null || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_closed || _pending == null || navigator == null || _routes.isEmpty) {
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
          GoRouter.of(navigator!.context)
              .pushAppRoute(destination.route, extra: destination.book),
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
