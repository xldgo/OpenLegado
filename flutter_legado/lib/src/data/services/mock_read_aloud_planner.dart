import '../../domain/contracts/read_aloud_planner.dart';
import '../../domain/models/read_aloud_content.dart';

/// 离线端不伪造切分能力；有需要的Mock场景应注入明确范围夹具。— Codex + Bridge
final class MockReadAloudPlanner implements ReadAloudPlanner {
  const MockReadAloudPlanner();
  @override
  Future<List<ReadAloudUnit>> plan(
    String content, {
    ReadAloudSplitMode mode = ReadAloudSplitMode.paragraph,
    String symbols = defaultReadAloudSplitSymbols,
    List<ReadAloudPageRange> pages = const [],
  }) async => throw UnsupportedError('离线模式未提供朗读内容范围夹具');
  @override
  Future<List<List<SpeechRequestPart>>> partition(
    String provider,
    List<String> texts,
  ) async => throw UnsupportedError('离线模式未提供云端请求范围夹具');
}
