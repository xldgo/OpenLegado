import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/reader/chinese_line_breaker.dart';

void main() {
  // 夹具由固定提交的原始 Kotlin 断行器实际运行生成，不由 Dart 实现回填。
  final fixture = jsonDecode(
    File('test/fixtures/reader/md3_line_breaks.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = fixture['cases'] as List<dynamic>;
  for (var index = 0; index < cases.length; index++) {
    test('MD3 原始断行器对照 $index：簇边界、UTF-16 偏移和宽度', () {
      final input = cases[index] as Map<String, dynamic>;
      final layout = ChineseLineBreaker(
        clusters: (input['clusters'] as List).cast<String>(),
        widths: (input['widths'] as List)
            .cast<num>()
            .map((value) => value.toDouble())
            .toList(),
        width: (input['width'] as num).toDouble(),
        firstLineWidth: (input['firstLineWidth'] as num).toDouble(),
        ideographWidth: (input['ideographWidth'] as num).toDouble(),
      );
      expect(layout.clusterStarts, input['clusterStarts']);
      expect(layout.sourceStarts, input['sourceStarts']);
      expect(layout.lineWidths, input['lineWidths']);
    });
  }
}
