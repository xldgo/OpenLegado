import '../../bridge/ffi.dart' as bridge;
import '../../bridge/read_aloud_dto.dart';
import '../../domain/contracts/read_aloud_planner.dart';
import '../../domain/models/read_aloud_content.dart';
import '../bridge/media_dto_mapping.dart';
import '../bridge/rust_errors.dart';

/// 正式端只映射范围与正文，不另行决定断点。— Codex + Bridge
final class RustReadAloudPlanner implements ReadAloudPlanner {
  const RustReadAloudPlanner();
  @override
  Future<List<ReadAloudUnit>> plan(
    String content, {
    ReadAloudSplitMode mode = ReadAloudSplitMode.paragraph,
    String symbols = defaultReadAloudSplitSymbols,
    List<ReadAloudPageRange> pages = const [],
  }) async {
    final result = await rustFuture(
      () => bridge.readAloudPlan(
        content: content,
        mode: switch (mode) {
          ReadAloudSplitMode.paragraph => ReadAloudSplitModeDto.paragraph,
          ReadAloudSplitMode.symbols => ReadAloudSplitModeDto.symbols,
          ReadAloudSplitMode.page => ReadAloudSplitModeDto.page,
        },
        symbols: symbols,
        pages: [
          for (final p in pages)
            ReadAloudRangeDto(
              start: BigInt.from(p.start),
              end: BigInt.from(p.end),
            ),
        ],
      ),
      operation: 'readAloudPlan',
    );
    return [
      for (final u in result)
        ReadAloudUnit(
          start: u.start.toInt(),
          text: content.substring(u.start.toInt(), u.end.toInt()),
          sourceParagraphIndex: u.sourceParagraphIndex.toInt(),
          isParagraphEnd: u.isParagraphEnd,
        ),
    ];
  }

  @override
  Future<List<List<SpeechRequestPart>>> partition(
    String provider,
    List<String> texts,
  ) async {
    final result = await rustFuture(
      () => bridge.cloudTtsPartition(
        provider: cloudProviderToDto(provider),
        texts: texts,
      ),
      operation: 'cloudTtsPartition',
    );
    return [
      for (var i = 0; i < result.length; i++)
        [
          for (final r in result[i].ranges)
            (
              start: r.start.toInt(),
              text: texts[i].substring(r.start.toInt(), r.end.toInt()),
            ),
        ],
    ];
  }
}
