/// 用户划分模式与请求长度分片分别建模。— Codex + UI
enum ReadAloudSplitMode { paragraph, symbols, page }

const readAloudSplitSymbols = '。！？…；，、：.!?;,:';
const defaultReadAloudSplitSymbols = '。！？…';

/// 源段落归属在按页或按符号切分后不变，原文终点按UTF-16长度派生。
final class ReadAloudUnit {
  const ReadAloudUnit({
    required this.start,
    required this.text,
    required this.sourceParagraphIndex,
    required this.isParagraphEnd,
  });
  final int start, sourceParagraphIndex;
  final String text;
  final bool isParagraphEnd;
  int get end => start + text.length;

  /// 入参是当前单元内的UTF-16偏移，只有最后一片继承真实段末。
  ReadAloudUnit slice(int from, int to) => ReadAloudUnit(
    start: start + from,
    text: text.substring(from, to),
    sourceParagraphIndex: sourceParagraphIndex,
    isParagraphEnd: isParagraphEnd && to == text.length,
  );
}

/// 云请求的技术长度分片不拥有原文段落语义。
typedef SpeechRequestPart = ({int start, String text});
typedef ReadAloudPageRange = ({int start, int end});
