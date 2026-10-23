import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_planner.dart';
import 'package:flutter_legado/src/domain/models/read_aloud_content.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// 编排用例显式指定分段结果；不模拟Rust的分段或请求长度规则。— Codex + UI
final class ReadAloudPlannerStub implements ReadAloudPlanner {
  ReadAloudPlannerStub(this.result);

  /// 当前用例将整份输入视为一个单元，不用于验证真实分段语义。
  ReadAloudPlannerStub.singleUnit()
    : result = ((text) => [
        ReadAloudUnit(
          start: 0,
          text: text,
          sourceParagraphIndex: 0,
          isParagraphEnd: true,
        ),
      ]);

  final List<ReadAloudUnit> Function(String) result;

  Override get providerOverride =>
      readAloudPlannerProvider.overrideWithValue(this);

  @override
  Future<List<ReadAloudUnit>> plan(
    String content, {
    ReadAloudSplitMode mode = ReadAloudSplitMode.paragraph,
    String symbols = defaultReadAloudSplitSymbols,
    List<ReadAloudPageRange> pages = const [],
  }) async => result(content);

  @override
  Future<List<List<SpeechRequestPart>>> partition(
    String provider,
    List<String> texts,
  ) => throw UnimplementedError('本用例未配置云端请求分片结果');
}
