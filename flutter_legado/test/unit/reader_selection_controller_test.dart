import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/features/reader/layout/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/features/reader/selection/reader_selection_controller.dart';

void main() {
  const source = '相同正文\n\n相同正文';
  const page = PageInfo(
    sourceText: source,
    totalHeight: 60,
    paragraphs: [
      ParagraphInfo(
        totalHeight: 24,
        startIndex: 0,
        endIndex: 4,
        lines: [
          LineInfo(
            words: ['相同正文'],
            width: 90,
            height: 24,
            startIndex: 0,
            endIndex: 4,
            indentWidth: 32,
          ),
        ],
      ),
      ParagraphInfo(
        totalHeight: 24,
        startIndex: 6,
        endIndex: 10,
        lines: [
          LineInfo(
            words: ['相同正文'],
            width: 90,
            height: 24,
            startIndex: 6,
            endIndex: 10,
            indentWidth: 32,
          ),
        ],
      ),
    ],
  );
  late ReaderSelectionController controller;
  setUp(() {
    controller = ReaderSelectionController()..configure(source, [page]);
  });
  tearDown(() => controller.dispose());

  test('折叠选区没有原文选区', () {
    controller.updateRange(0, 0);
    expect(controller.value, isFalse);
  });
  test('原生选区从正文首字起算，不需要跨过虚拟缩进', () {
    controller.updateRange(0, 1);
    expect(controller.selection!.text, '相');
    expect(controller.selection!.start, 0);
    expect(controller.selection!.end, 1);
  });
  test('全选排除虚拟缩进并保留原文段落分隔', () {
    controller.updateRange(0, 8);
    expect(controller.selection!.text, source);
    expect(controller.selection!.start, 0);
    expect(controller.selection!.end, 10);
  });
  test('重复文字按显示偏移定位到第二段', () {
    controller.updateRange(4, 6);
    expect(controller.selection!.text, '相同');
    expect(controller.selection!.start, 6);
    expect(controller.selection!.end, 8);
  });
  test('选区结束在段落边界时不会带入下一段换行', () {
    controller.updateRange(0, 4);
    expect(controller.selection!.text, '相同正文');
    expect(controller.selection!.end, 4);
  });
  test('反向拖动使用相同原文区间', () {
    controller.updateRange(6, 4);
    expect(controller.selection!.text, '相同');
    expect(controller.selection!.start, 6);
  });
  test('原生先清空选区后仍消费本次关闭点按', () {
    controller.updateRange(2, 4);
    controller.onPointerDown();
    controller.updateRange(0, 0);
    expect(controller.consumeTap(), isTrue);
    expect(controller.consumeTap(), isFalse);
  });
  test('重新配置正文清空旧选区并通知手势层', () {
    controller.updateRange(2, 4);
    var changes = 0;
    controller.addListener(() => changes++);
    controller.configure('新正文', const []);
    expect(controller.value, isFalse);
    expect(changes, 1);
  });
}
