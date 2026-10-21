library;

/// 段落布局引擎单元测试
///
/// 本文件验证样式配置与布局结果模型；断行、分页规则由原始 Kotlin 对照测试覆盖。

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';

void main() {
  group('ParagraphConfig - 样式配置测试', () {
    late ParagraphConfig defaultConfig;

    setUp(() {
      // [A-4 | 2026-09-20] 颜色改必填后显式传原默认值（白底/黑字），
      // 本组用例仍验证其余几何默认值与颜色透传
      defaultConfig = const ParagraphConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
      );
    });

    test('ParagraphConfig - 默认值验证', () {
      expect(defaultConfig.fontSize, equals(16.0));
      expect(defaultConfig.lineHeight, equals(1.2));
      expect(defaultConfig.paragraphSpacing, equals(2.0));
      expect(defaultConfig.indent, equals(0.0));
      expect(defaultConfig.justify, isTrue);
      expect(defaultConfig.textBottomJustify, isTrue);
      expect(
        defaultConfig.copyWith(textBottomJustify: false).textBottomJustify,
        isFalse,
      );
      expect(defaultConfig.backgroundColor, equals(Colors.white));
      expect(defaultConfig.textColor, equals(Colors.black));
    });

    test('ParagraphConfig - 自定义值', () {
      final customConfig = const ParagraphConfig(
        fontSize: 14.0,
        lineHeight: 1.8,
        paragraphSpacing: 10.0,
        indent: 32.0,
        justify: false,
        backgroundColor: Colors.grey,
        textColor: Colors.blue,
      );

      expect(customConfig.fontSize, equals(14.0));
      expect(customConfig.lineHeight, equals(1.8));
      expect(customConfig.paragraphSpacing, equals(10.0));
      expect(customConfig.indent, equals(32.0));
      expect(customConfig.justify, isFalse);
      expect(customConfig.backgroundColor, equals(Colors.grey));
      expect(customConfig.textColor, equals(Colors.blue));
    });

    test('ParagraphConfig - copyWith 复制并修改', () {
      final modified = defaultConfig.copyWith(fontSize: 18.0);

      expect(modified.fontSize, equals(18.0));
      expect(modified.lineHeight, equals(1.2));
      expect(modified.paragraphSpacing, equals(2.0));
    });

    test('ParagraphConfig - copyWith 全修改', () {
      final modified = defaultConfig.copyWith(
        fontSize: 20.0,
        lineHeight: 2.0,
        paragraphSpacing: 12.0,
        indent: 24.0,
        justify: false,
        backgroundColor: Colors.red,
        textColor: Colors.green,
      );

      expect(modified.fontSize, equals(20.0));
      expect(modified.lineHeight, equals(2.0));
      expect(modified.paragraphSpacing, equals(12.0));
      expect(modified.indent, equals(24.0));
      expect(modified.justify, isFalse);
      expect(modified.backgroundColor, equals(Colors.red));
      expect(modified.textColor, equals(Colors.green));
    });

    test('ParagraphConfig - copyWith 空参数保持原值', () {
      final modified = defaultConfig.copyWith();

      expect(modified.fontSize, equals(defaultConfig.fontSize));
      expect(modified.lineHeight, equals(defaultConfig.lineHeight));
      expect(modified.paragraphSpacing, equals(defaultConfig.paragraphSpacing));
      expect(modified.indent, equals(defaultConfig.indent));
      expect(modified.justify, equals(defaultConfig.justify));
      expect(modified.backgroundColor, equals(defaultConfig.backgroundColor));
      expect(modified.textColor, equals(defaultConfig.textColor));
    });

    test('ParagraphConfig - 不可变性验证', () {
      final originalFontSize = defaultConfig.fontSize;
      final modified = defaultConfig.copyWith(fontSize: 24.0);

      expect(modified.fontSize, equals(24.0));
      expect(defaultConfig.fontSize, equals(originalFontSize));
    });
  });

  group('LineInfo - 行信息测试', () {
    test('LineInfo - 创建有效对象', () {
      const lineInfo = LineInfo(
        words: ['测', '试'],
        width: 100.0,
        height: 24.0,
        startIndex: 0,
        endIndex: 2,
      );

      expect(lineInfo.words.length, equals(2));
      expect(lineInfo.width, equals(100.0));
      expect(lineInfo.height, equals(24.0));
      expect(lineInfo.startIndex, equals(0));
      expect(lineInfo.endIndex, equals(2));
    });

    test('LineInfo - 单字行', () {
      const lineInfo = LineInfo(
        words: ['一'],
        width: 50.0,
        height: 24.0,
        startIndex: 0,
        endIndex: 1,
      );

      expect(lineInfo.words.length, equals(1));
      expect(lineInfo.words[0], equals('一'));
    });

    test('LineInfo - 多行字符集合', () {
      final lineInfo = LineInfo(
        words: ['第', '一', '章', '标', '题'],
        width: 200.0,
        height: 28.0,
        startIndex: 0,
        endIndex: 5,
      );

      expect(lineInfo.words.join(''), equals('第一章标题'));
      expect(lineInfo.width, equals(200.0));
    });

    test('LineInfo - 空字符列表', () {
      const lineInfo = LineInfo(
        words: [],
        width: 0.0,
        height: 24.0,
        startIndex: 0,
        endIndex: 0,
      );

      expect(lineInfo.words.isEmpty, isTrue);
      expect(lineInfo.width, equals(0.0));
    });
  });

  group('ParagraphInfo - 段落信息测试', () {
    test('ParagraphInfo - 创建有效对象', () {
      final lines = [
        const LineInfo(
          words: ['第'],
          width: 50.0,
          height: 24.0,
          startIndex: 0,
          endIndex: 1,
        ),
        const LineInfo(
          words: ['一'],
          width: 50.0,
          height: 24.0,
          startIndex: 1,
          endIndex: 2,
        ),
      ];
      final paraInfo = ParagraphInfo(
        lines: lines,
        totalHeight: 48.0,
        startIndex: 0,
        endIndex: 2,
      );

      expect(paraInfo.lines.length, equals(2));
      expect(paraInfo.totalHeight, equals(48.0));
      expect(paraInfo.startIndex, equals(0));
      expect(paraInfo.endIndex, equals(2));
    });

    test('ParagraphInfo - 单行段落', () {
      final lines = [
        const LineInfo(
          words: ['这是一句话'],
          width: 150.0,
          height: 24.0,
          startIndex: 0,
          endIndex: 5,
        ),
      ];
      final paraInfo = ParagraphInfo(
        lines: lines,
        totalHeight: 24.0,
        startIndex: 0,
        endIndex: 5,
      );

      expect(paraInfo.lines.length, equals(1));
      expect(paraInfo.totalHeight, equals(24.0));
    });

    test('ParagraphInfo - 多行复杂段落', () {
      final lines = List.generate(
        10,
        (i) => LineInfo(
          words: ['行'],
          width: 50.0,
          height: 24.0,
          startIndex: i,
          endIndex: i + 1,
        ),
      );

      final paraInfo = ParagraphInfo(
        lines: lines,
        totalHeight: 10.0 * 24.0,
        startIndex: 0,
        endIndex: 10,
      );

      expect(paraInfo.lines.length, equals(10));
      expect(paraInfo.totalHeight, equals(240.0));
    });

    test('ParagraphInfo - 空段落', () {
      const paraInfo = ParagraphInfo(
        lines: [],
        totalHeight: 0.0,
        startIndex: 0,
        endIndex: 0,
      );

      expect(paraInfo.lines.isEmpty, isTrue);
      expect(paraInfo.totalHeight, equals(0.0));
    });
  });

  group('PageInfo - 页面信息测试', () {
    test('PageInfo - 创建有效对象', () {
      final paragraphs = [
        const ParagraphInfo(
          lines: [],
          totalHeight: 0,
          startIndex: 0,
          endIndex: 0,
        ),
      ];
      final pageInfo = PageInfo(paragraphs: paragraphs, totalHeight: 0);

      expect(pageInfo.paragraphs.length, equals(1));
      expect(pageInfo.totalHeight, equals(0));
    });

    test('PageInfo - 空页面', () {
      const pageInfo = PageInfo(paragraphs: [], totalHeight: 0);

      expect(pageInfo.paragraphs.isEmpty, isTrue);
      expect(pageInfo.totalHeight, equals(0));
    });

    test('PageInfo - 多段落页面', () {
      final paragraphs = [
        const ParagraphInfo(
          lines: [],
          totalHeight: 100.0,
          startIndex: 0,
          endIndex: 50,
        ),
        const ParagraphInfo(
          lines: [],
          totalHeight: 150.0,
          startIndex: 51,
          endIndex: 100,
        ),
      ];
      final pageInfo = PageInfo(paragraphs: paragraphs, totalHeight: 250.0);

      expect(pageInfo.paragraphs.length, equals(2));
      expect(pageInfo.totalHeight, equals(250.0));
    });

    test('PageInfo - 多行段落组合', () {
      final paragraphLines = [
        const LineInfo(
          words: ['第一'],
          width: 80.0,
          height: 24.0,
          startIndex: 0,
          endIndex: 2,
        ),
        const LineInfo(
          words: ['行'],
          width: 30.0,
          height: 24.0,
          startIndex: 2,
          endIndex: 3,
        ),
      ];

      final firstPara = ParagraphInfo(
        lines: paragraphLines,
        totalHeight: 48.0,
        startIndex: 0,
        endIndex: 3,
      );

      final secondParaLines = [
        const LineInfo(
          words: ['第二段'],
          width: 120.0,
          height: 24.0,
          startIndex: 3,
          endIndex: 6,
        ),
      ];

      final secondPara = ParagraphInfo(
        lines: secondParaLines,
        totalHeight: 24.0,
        startIndex: 3,
        endIndex: 6,
      );

      final pageInfo = PageInfo(
        paragraphs: [firstPara, secondPara],
        totalHeight: 72.0,
      );

      expect(pageInfo.paragraphs.length, equals(2));
      expect(pageInfo.totalHeight, equals(72.0));
    });
  });
}
