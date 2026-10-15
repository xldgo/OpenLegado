import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../domain/contracts/rss_source_repository.dart';
import '../domain/contracts/rss_article_repository.dart';
import '../domain/contracts/rss_read_record_repository.dart';
import '../domain/contracts/rss_star_repository.dart';

/// 复用应用装配实例，消费者和测试可分别注入订阅数据依赖。— Codex + UI
final rssSourceRepositoryProvider = Provider<RssSourceRepository>(
  (ref) => ref.watch(bookApiProvider).rssSourceRepository,
);

final rssArticleRepositoryProvider = Provider<RssArticleRepository>(
  (ref) => ref.watch(bookApiProvider).rssArticleRepository,
);

final rssReadRecordRepositoryProvider = Provider<RssReadRecordRepository>(
  (ref) => ref.watch(bookApiProvider).rssReadRecordRepository,
);

final rssStarRepositoryProvider = Provider<RssStarRepository>(
  (ref) => ref.watch(bookApiProvider).rssStarRepository,
);
