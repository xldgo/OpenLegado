import 'package:flutter_legado/src/utils/book_metadata_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('空字段、既有占位文案和异常元信息不显示', () {
    for (final value in [
      null,
      '',
      '   ',
      'NaN',
      'nan : NaN',
      '暂无专辑',
      '暂无简介',
      r'9.9分|{{$.x}}',
      r'{$未闭合',
    ]) {
      expect(isVisibleBookMetadata(value), isFalse, reason: '$value');
    }
  });
  test('有效元信息与含有效内容的混合字符串保持可见', () {
    for (final value in [
      '唐家三少',
      '9.9分',
      '298.6万字',
      'NaN技术详解',
      'NaN,轻小说',
      '{说明}',
      'null',
    ]) {
      expect(isVisibleBookMetadata(value), isTrue, reason: value);
    }
  });
}
