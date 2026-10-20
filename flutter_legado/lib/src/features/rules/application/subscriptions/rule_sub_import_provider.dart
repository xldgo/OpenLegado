import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/bootstrap/source_import_factory.dart';
import '../../../../providers/network_provider.dart';
import '../../../../providers/replace_rule_repository_provider.dart';
import '../../../../providers/rss_repository_provider.dart';
import 'rule_sub_import_service.dart';

final ruleSubImportServiceProvider = Provider<RuleSubImportService>(
  (ref) => RuleSubImportService(
    network: ref.watch(networkServiceProvider),
    fetchBookSources: ref
        .watch(sourceImportServiceProvider)
        .fetchSourcesFromUrl,
    rss: ref.watch(rssSourceRepositoryProvider),
    replaceRules: ref.watch(replaceRuleRepositoryProvider),
  ),
);
