import 'package:flutter_riverpod/flutter_riverpod.dart';

// 领域能力由应用装配提供，读取仓储不隐式初始化原生库。— Codex + UI
export '../app/bootstrap/application_dependencies.dart'
    show highlightRepositoryProvider, highlightRuleRepositoryProvider;

/// 本地规则写入成功后失效阅读器的规则与章节样式快照。
class HighlightRuleRevision extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}

final highlightRuleRevisionProvider =
    NotifierProvider<HighlightRuleRevision, int>(HighlightRuleRevision.new);
