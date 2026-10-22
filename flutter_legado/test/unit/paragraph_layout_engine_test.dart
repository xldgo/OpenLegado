import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/services/reader_layout_service.dart';
import 'package:flutter_legado/src/features/reader/layout/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/features/reader/layout/text_layout_environment.dart';

/// 只记录送出的测量参数，不提供断行或分页算法。— Codex + Bridge
class _RecordingTransport implements ReaderLayoutTransport {
  Map<String, Object?>? config;
  final blocks = <Map<String, Object?>>[];
  final id = Object();

  ReaderLayoutReply get reply => ReaderLayoutReply.fromMap({
    'schemaVersion': 1,
    'sessionId': id,
    'pages': <Object?>[],
    'rustMicros': 0,
    'textStyles': <Object?>[],
    'glyphs': {
      'count': 0,
      'text': '',
      'geometry': '',
      'positions': '',
      'extras': <String, dynamic>{},
    },
  });

  @override
  Future<ReaderLayoutReply> begin(Map<String, Object?> config) async {
    this.config = config;
    return reply;
  }

  @override
  Future<ReaderLayoutReply> push(
    Object id,
    List<Map<String, Object?>> blocks,
  ) async {
    this.blocks.addAll(blocks);
    return reply;
  }

  @override
  Future<ReaderLayoutReply> finish(Object id) async => reply;

  @override
  Future<void> cancel(Object id) async {}
}

class _Context extends Fake implements BuildContext {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ParagraphLayoutEngine engine(
    _RecordingTransport transport, {
    bool chinese = true,
  }) => ParagraphLayoutEngine(
    context: _Context(),
    transport: transport,
    config: ParagraphConfig(
      fontSize: 16,
      lineHeight: 1.5,
      paragraphSpacing: 8,
      useZhLayout: chinese,
      backgroundColor: const Color(0xffffffff),
      textColor: const Color(0xff000000),
    ),
  );

  for (final chinese in [true, false]) {
    test('中文排版开关$chinese和实际区域尺寸传入排版契约', () async {
      final transport = _RecordingTransport();
      await engine(
        transport,
        chinese: chinese,
      ).paginateChapter('测试正文。', 120.9, 200.7);
      expect(transport.config!['breakMode'], chinese ? 'chinese' : 'plain');
      expect(transport.config!['viewportWidthPx'], 120);
      expect(transport.config!['viewportHeightPx'], 200);
      expect(transport.config!['lineSpacingMultiplier'], 1.5);
      expect(
        transport.config!['paragraphSpacingPx'],
        closeTo((transport.config!['lineHeightPx']! as double) * .8, .001),
      );
      expect(transport.config!['textBottomJustify'], isTrue);
      final block = transport.blocks.single['value']! as Map;
      expect(block['lineSpacingMultiplier'], 1.5);
      expect(transport.blocks.single['type'], 'paragraph');
    });
  }

  for (final source in ['', '   \n\n   ']) {
    test('空内容或纯空白不生成测量正文块：${source.length}', () async {
      final transport = _RecordingTransport();
      expect(
        await engine(transport).paginateChapter(source, 300, 600),
        isEmpty,
      );
      expect(transport.blocks, isEmpty);
    });
  }

  test('字形簇索引与UTF-16偏移分别映射，拒绝字符中间位置', () {
    final mapping = TextClusterMap('甲😀乙e\u0301丙👨‍👩‍👧‍👦丁');
    expect(mapping.sourceOffsets[2], 3);
    expect(mapping.clusterIndex(3), 2);
    expect(() => mapping.clusterIndex(2), throwsArgumentError);
  });

  test('分段保留混合换行、空白与重复段落的真实原文偏移', () {
    const source = '\r\n　首段  \r\n\n重复段。\r重复段。\n\n';
    final paragraphs = splitChapterParagraphs(source);
    expect(paragraphs.map((p) => p.text), ['首段', '重复段。', '重复段。']);
    expect(paragraphs[0].startIndex, source.indexOf('首段'));
    expect(paragraphs[2].startIndex, source.lastIndexOf('重复段。'));
    for (final paragraph in paragraphs) {
      expect(
        source.substring(paragraph.startIndex, paragraph.endIndex),
        paragraph.text,
      );
    }
  });
  test('连续滚动不进行底部对齐', () async {
    final transport = _RecordingTransport();
    await engine(transport).paginateChapter('正文', 300, double.infinity);
    expect(transport.config!['textBottomJustify'], isFalse);
  });
}
