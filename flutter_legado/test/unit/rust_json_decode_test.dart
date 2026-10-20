import 'package:flutter_legado/src/data/bridge/rust_json_decode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('共用解码保留裸数组及对象的原始字段与类型', () {
    expect(decodeRustJsonList('[{"id":1,"content":"原备注"}]', 'bookApi'), [
      {'id': 1, 'content': '原备注'},
    ]);
    expect(decodeRustJsonList('[]', 'bookApi'), isEmpty);
    expect(decodeRustJsonMap('{"enabled":true,"value":null}', 'settings'), {
      'enabled': true,
      'value': null,
    });
  });

  test('结构漂移和错误 JSON 均失败，保持既有错误上下文', () {
    for (final json in ['{"data":[]}', 'null', '1', '"文本"']) {
      expect(
        () => decodeRustJsonList(json, 'bookApi'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            startsWith('bookApi（Rust JSON 列表解码）: 期望 JSON 数组'),
          ),
        ),
      );
    }
    expect(() => decodeRustJsonList('{', 'bookApi'), throwsFormatException);
    expect(() => decodeRustJsonMap('[]', 'settings'), throwsFormatException);
    expect(() => decodeRustJsonMap('{', 'settings'), throwsFormatException);
  });

  test('格式错误内容预览保持原来的 120 字符上限', () {
    final json = '{"content":"${'正文' * 100}"}';
    expect(
      () => decodeRustJsonList(json, 'bookApi'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          endsWith('原始内容前 120 字符：${json.substring(0, 120)}'),
        ),
      ),
    );
  });
}
