import 'chapter_layout.dart';
import 'text_layout_environment.dart';

/// 消费最终行布局；正文允许跨页，段尾余量继续容纳下一段。
class LinePaginator {
  final String sourceText;
  final TextLayoutEnvironment? environment;
  final double pageHeight;
  final double? firstPageHeight;
  final double paragraphSpacing;
  final List<PageInfo> completedPages = [];
  final List<ParagraphInfo> _paragraphs = [];
  double _height = 0;

  LinePaginator({
    required this.sourceText,
    required this.pageHeight,
    required this.paragraphSpacing,
    this.firstPageHeight,
    this.environment,
  });

  double get _capacity =>
      completedPages.isEmpty ? firstPageHeight ?? pageHeight : pageHeight;

  void _flushPage() {
    if (_paragraphs.isEmpty) return;
    completedPages.add(
      PageInfo(
        paragraphs: List.unmodifiable(_paragraphs),
        totalHeight: _height,
        sourceText: sourceText,
        textEnvironment: environment,
      ),
    );
    _paragraphs.clear();
    _height = 0;
  }

  void addParagraph(ParagraphInfo paragraph, int paragraphIndex) {
    var lines = <LineInfo>[];
    var fragmentHeight = 0.0;
    var spacing = _paragraphs.isEmpty ? 0.0 : paragraphSpacing;
    void flushFragment(bool isEnd) {
      if (lines.isEmpty) return;
      _paragraphs.add(
        ParagraphInfo(
          lines: List.unmodifiable(lines),
          totalHeight: fragmentHeight,
          startIndex: lines.first.startIndex,
          endIndex: lines.last.endIndex,
          chapterParagraphIndex: paragraphIndex,
          isParagraphEnd: isEnd,
          spacingBefore: spacing,
        ),
      );
      lines = [];
      fragmentHeight = 0;
    }

    for (final line in paragraph.lines) {
      if (line.height > pageHeight + .001) {
        throw const ReaderLayoutBoundsException('阅读区域太矮，请扩大窗口或减小字号');
      }
      if (_height == 0 && line.height > _capacity + .001) {
        throw const ReaderLayoutBoundsException('章节标题后空间不足，请扩大窗口或减小字号');
      }
      final gap = lines.isEmpty ? spacing : 0.0;
      if (_height > 0 && _height + gap + line.height > _capacity + .001) {
        flushFragment(false);
        _flushPage();
        spacing = 0;
      }
      _height += (lines.isEmpty ? spacing : 0) + line.height;
      fragmentHeight += line.height;
      lines.add(line);
    }
    flushFragment(paragraph.isParagraphEnd);
  }

  List<PageInfo> finish() {
    _flushPage();
    return List.unmodifiable(completedPages);
  }
}
