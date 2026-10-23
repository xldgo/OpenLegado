import '../models/read_aloud_content.dart';

/// 内容与请求切分只返回当前输入范围，不拥有播放会话。— Codex + Bridge
abstract interface class ReadAloudPlanner {
  Future<List<ReadAloudUnit>> plan(
    String content, {
    ReadAloudSplitMode mode = ReadAloudSplitMode.paragraph,
    String symbols = defaultReadAloudSplitSymbols,
    List<ReadAloudPageRange> pages = const [],
  });
  Future<List<List<SpeechRequestPart>>> partition(
    String provider,
    List<String> texts,
  );
}
