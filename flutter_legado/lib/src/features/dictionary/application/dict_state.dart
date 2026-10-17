import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/models.dart';

part 'dict_state.freezed.dart';

/// 字典查询页状态
///
/// 规则来自DictRuleRepository，查询结果来自DictionaryService；不另存规则配置。
@freezed
abstract class DictState with _$DictState {
  const factory DictState({
    /// 在线词典规则列表
    @Default([]) List<DictRule> rules,

    /// 当前查询的单词（null 表示尚未查询）
    String? queriedWord,

    /// 本地词典命中结果（null 表示未查询或未收录）
    DictEntry? result,

    /// 正在加载规则
    @Default(false) bool isLoading,

    /// 错误信息
    String? error,
  }) = _DictState;
}
