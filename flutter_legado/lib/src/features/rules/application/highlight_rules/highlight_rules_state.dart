import '../../../../domain/models/highlight_rule.dart';

/// 高亮规则列表页状态
class HighlightRulesState {
  const HighlightRulesState({
    this.rules = const [],
    this.isLoading = true,
    this.error,
  });

  final List<HighlightRule> rules;
  final bool isLoading;
  final String? error;

  HighlightRulesState copyWith({
    List<HighlightRule>? rules,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HighlightRulesState(
      rules: rules ?? this.rules,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
