import 'package:material_ui/material_ui.dart';

/// 全局路由观察器：为「返回重现时需刷新」的页面提供路由回调。
///
/// 对齐原版 ChapterListFragment 经 EventBus.SAVE_CONTENT 增量刷新目录
/// 云图标的语义：从阅读器返回目录页（同一页面实例重现）时，阅读过程
/// 中写入的缓存章节应立即体现为实心云图标、当前章节信息同步更新。
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// 系统栏跟踪独立页面；弹层上方打开页面时，也能找到下方原页面。
class SystemBarRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final _pages = <PageRoute<dynamic>>[];

  @override
  void subscribe(RouteAware routeAware, PageRoute<dynamic> route) {
    super.subscribe(routeAware, route);
    if (_pages.isNotEmpty && route != _pages.last) routeAware.didPushNext();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute<dynamic>) return;
    if (previousRoute == null) _pages.clear();
    final previousPage = _pages.lastOrNull;
    _pages.add(route);
    super.didPush(route, previousPage);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute<dynamic>) return;
    _pages.remove(route);
    super.didPop(route, _pages.lastOrNull);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final wasCurrent = _pages.isNotEmpty && _pages.last == route;
    if (!_pages.remove(route)) return;
    if (wasCurrent) super.didPop(route, _pages.lastOrNull);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute is PageRoute<dynamic>
        ? _pages.indexOf(oldRoute)
        : -1;
    if (index < 0) {
      if (newRoute != null) didPush(newRoute, _pages.lastOrNull);
      return;
    }
    final wasCurrent = index == _pages.length - 1;
    if (newRoute is PageRoute<dynamic>) {
      _pages[index] = newRoute;
    } else {
      _pages.removeAt(index);
    }
    if (wasCurrent && oldRoute != null) {
      super.didPop(oldRoute, _pages.lastOrNull);
    }
  }
}

final systemBarRouteObserver = SystemBarRouteObserver();
