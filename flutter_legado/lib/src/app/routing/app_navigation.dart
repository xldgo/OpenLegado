import 'package:go_router/go_router.dart';

import '../../models/book.dart';
import '../../widgets/book_cover.dart';
import 'route_arguments.dart';
import 'route_names.dart';

export 'package:go_router/go_router.dart' show GoRouter;

/// 标识放入可重建地址，界面快照与动效对象仍只存于extra。— Codex + UI
String appRouteLocation(String path, Object? extra) {
  final uri = Uri.parse(path);
  final query = <String, dynamic>{...uri.queryParametersAll};
  final bookUrl = switch (extra) {
    Book(:final bookUrl) => bookUrl,
    BookCoverOrigin(:final bookUrl) => bookUrl,
    ReaderRouteArgs(:final bookUrl) => bookUrl,
    ContentSearchRouteArgs(:final book) => book.bookUrl,
    VideoScreenArgs(:final book) => book?.bookUrl,
    _ => null,
  };
  if (bookUrl != null && bookUrl.isNotEmpty) query['book'] = bookUrl;
  if (path == AppRoutes.readerComic && extra is String) query['book'] = extra;
  if (extra is SearchRouteArgs) {
    if (extra.query != null) query['q'] = extra.query;
    if (extra.sourceUrls != null) query['source'] = extra.sourceUrls;
    if (extra.groups != null) query['group'] = extra.groups;
  }
  return uri.replace(queryParameters: query.isEmpty ? null : query).toString();
}

extension AppRouteNavigation on GoRouter {
  Future<T?> pushAppRoute<T extends Object?>(String path, {Object? extra}) =>
      push<T>(appRouteLocation(path, extra), extra: extra);
  Future<T?> replaceAppRoute<T extends Object?>(String path, {Object? extra}) =>
      pushReplacement<T>(appRouteLocation(path, extra), extra: extra);
}
