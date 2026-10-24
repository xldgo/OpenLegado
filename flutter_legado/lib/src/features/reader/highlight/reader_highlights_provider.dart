import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/highlight_rule.dart';
import '../../../domain/contracts/highlight_rule_repository.dart';
import '../../../providers/highlight_repository_provider.dart';
import 'reader_highlight_resources.dart';

final readerHighlightResourcesProvider =
    Provider.autoDispose<ReaderHighlightResources>((ref) {
      final resources = ReaderHighlightResources();
      ref.onDispose(resources.dispose);
      return resources;
    });

typedef HighlightChapterKey = ({
  String text,
  String title,
  String bookName,
  String origin,
  String configName,
});

class ReaderHighlights {
  const ReaderHighlights({this.body = const [], this.title = const []});
  final List<HighlightMatch> body;
  final List<HighlightMatch> title;
  bool get isEmpty => body.isEmpty && title.isEmpty;
}

typedef HighlightBookKey = ({String bookName, String origin});
final readerHighlightRulesProvider = FutureProvider.autoDispose
    .family<List<HighlightRule>, HighlightBookKey>((ref, key) {
      ref.watch(highlightRuleRevisionProvider);
      return ref
          .watch(highlightRuleRepositoryProvider)
          .highlightRuleFindEnabled(bookName: key.bookName, origin: key.origin);
    });

final readerHighlightsProvider = FutureProvider.autoDispose
    .family<ReaderHighlights, HighlightChapterKey>((ref, key) async {
      ref.watch(highlightRuleRevisionProvider);
      final repo = ref.watch(highlightRuleRepositoryProvider);
      final resources = ref.watch(readerHighlightResourcesProvider);
      final rules = await ref.watch(
        readerHighlightRulesProvider((
          bookName: key.bookName,
          origin: key.origin,
        )).future,
      );
      return loadReaderHighlights(repo, resources, rules, key);
    });

/// 当前章与相邻章预排复用同一编排；预排生命周期由现有分页任务持有。
Future<ReaderHighlights> loadReaderHighlights(
  HighlightRuleRepository repo,
  ReaderHighlightResources resources,
  List<HighlightRule> rules,
  HighlightChapterKey key,
) async {
  if (rules.isEmpty) return const ReaderHighlights();
  final matched = await Future.wait([
    repo.matchText(rules, key.text, configName: key.configName),
    repo.matchText(rules, key.title, isTitle: true, configName: key.configName),
  ]);
  await resources.prepare([...matched[0], ...matched[1]]);
  return ReaderHighlights(body: matched[0], title: matched[1]);
}
