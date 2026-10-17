import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_legado/src/services/reader_layout_service.dart';
import 'package:flutter_legado/src/services/reader_layout_data.dart';
import 'package:flutter_legado/src/widgets/reader/layout_diagnostics.dart';
import 'package:flutter_legado/src/widgets/reader/reader_layout_element.dart';

class _Transport implements ReaderLayoutTransport {
  final calls = <String>[];
  final beginResult = Completer<ReaderLayoutReply>();
  final pending = <Completer<ReaderLayoutReply>>[];
  bool deferPush = false;
  ReaderLayoutReply reply({String id = '会话', List<Object> pages = const []}) =>
      ReaderLayoutReply.fromMap({
        'schemaVersion': 1,
        'sessionId': id,
        'pages': [
          for (final page in pages)
            <String, dynamic>{...page as Map, 'elements': []},
        ],
        'rustMicros': 10,
        'textStyles': [],
        'glyphs': {
          'count': 0,
          'text': '',
          'geometry': '',
          'positions': '',
          'extras': <String, dynamic>{},
        },
      });
  @override
  Future<ReaderLayoutReply> begin(Map<String, Object?> config) {
    calls.add('begin');
    expect(config, isA<Map<String, Object?>>());
    return beginResult.future;
  }

  @override
  Future<ReaderLayoutReply> push(
    Object sessionId,
    List<Map<String, Object?>> blocks,
  ) {
    calls.add('push');
    expect(blocks, isList);
    if (!deferPush) return Future.value(reply());
    final completion = Completer<ReaderLayoutReply>();
    pending.add(completion);
    return completion.future;
  }

  @override
  Future<ReaderLayoutReply> finish(Object sessionId) async {
    calls.add('finish');
    return reply(
      pages: [
        {'最后一页': true},
      ],
    );
  }

  @override
  Future<void> cancel(Object sessionId) async {
    calls.add('cancel');
  }
}

void main() {
  String floats(List<double> values) {
    final data = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      data.setFloat32(i * 4, values[i], Endian.little);
    }
    return base64Encode(data.buffer.asUint8List());
  }

  String integers(List<int> values) {
    final data = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      data.setUint32(i * 4, values[i], Endian.little);
    }
    return base64Encode(data.buffer.asUint8List());
  }

  Map<String, dynamic> compactReply({Map<String, dynamic>? extras}) => {
    'schemaVersion': 1,
    'sessionId': '会话',
    'rustMicros': 1,
    'textStyles': [
      {'fontSizePx': 18, 'italic': true},
    ],
    'glyphs': {
      'count': 1,
      'text': '😀',
      'geometry': floats([4, 2, 22, 26, 21]),
      'positions': integers([9, 3, 0, 2]),
      'extras': {
        '0':
            extras ??
            {
              'readAloud': true,
              'link': 'https://example.test',
              'backgroundFrameLeftPx': 2.5,
            },
      },
    },
    'pages': [
      {
        'elements': [
          0,
          {'type': 'review', 'count': 23},
        ],
      },
    ],
  };
  test('共享字形无损恢复 UTF-16 原文、样式、几何和额外标记，非文本保留', () {
    final encoded = compactReply();
    expect(encoded.containsKey('elementEncoding'), false);
    final reply = ReaderLayoutReply.decode(jsonEncode(encoded));
    final elements = reply.pages.single['elements'] as List;
    final text = elements.first as Map;
    expect(text['value'], '😀');
    expect(text['chapterPosition'], 9);
    expect(text['paragraphIndex'], 3);
    expect(text['bounds'], {
      'left': 4.0,
      'top': 2.0,
      'right': 22.0,
      'bottom': 26.0,
    });
    expect(text['style'], {'fontSizePx': 18, 'italic': true});
    expect(text['readAloud'], true);
    expect(text['selected'], false);
    expect(text['link'], 'https://example.test');
    expect(text['backgroundFrameLeftPx'], 2.5);
    expect(elements.last, {'type': 'review', 'count': 23});
  });
  test('拒绝错误样式索引、非有限坐标、反向范围、坏缓冲和 UTF-16 截断', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (v) => v['glyphs']['positions'] = integers([9, 3, 1, 2]),
      (v) => v['glyphs']['positions'] = integers([0xffffffff, 3, 0, 2]),
      (v) => v['glyphs']['positions'] = integers([9, 0xffffffff, 0, 2]),
      (v) => v['glyphs']['positions'] = integers([9, 3, 0, 1]),
      (v) => v['glyphs']['positions'] = integers([9, 3, 0, 3]),
      (v) => v['glyphs']['geometry'] = floats([double.nan, 2, 22, 26, 21]),
      (v) => v['glyphs']['geometry'] = floats([4, 2, double.infinity, 26, 21]),
      (v) => v['glyphs']['geometry'] = floats([4, 2, 1, 26, 21]),
      (v) => v['glyphs']['geometry'] = floats([4, 2, 22, 1, 21]),
      (v) => v['glyphs']['geometry'] = floats([4, 2, 22, 26]),
      (v) => v['glyphs']['geometry'] = '坏缓冲',
      (v) => v['glyphs']['count'] = '1',
      (v) => v['glyphs']['text'] = '',
      (v) => v['pages'][0]['elements'][0] = 1,
      (v) => v['pages'][0]['elements'][0] = -1,
      (v) => v['pages'][0]['elements'][0] = [0, 0],
      (v) => v['glyphs']['extras'] = {
        '1': {'selected': true},
      },
      (v) => v['glyphs']['extras'] = {
        '00': {'selected': true},
      },
    ];
    for (var i = 0; i < mutations.length; i++) {
      final value = compactReply();
      mutations[i](value);
      expect(
        () => ReaderLayoutReply.decode(jsonEncode(value)),
        throwsFormatException,
        reason: '无效数据 $i',
      );
    }
    for (final fields in [
      {'value': '覆盖原文'},
      {'selected': null},
      {'readAloud': 'true'},
      {'link': 12},
      {'backgroundFrameLeftPx': '2.5'},
    ]) {
      expect(
        () =>
            ReaderLayoutReply.decode(jsonEncode(compactReply(extras: fields))),
        throwsFormatException,
      );
    }
  });
  test('字形只读视图支持完整字段枚举、序列化和显式空值', () {
    final reply = ReaderLayoutReply.decode(
      jsonEncode(
        compactReply(
          extras: {
            'selected': true,
            'link': null,
            'emphasisUnderline': {'color': 123},
          },
        ),
      ),
    );
    final elements = reply.pages.single['elements'] as List;
    final text = elements.first as Map;
    expect(text.keys, hasLength(19));
    expect(text.containsKey('markingId'), isTrue);
    expect(text.containsKey('未知'), isFalse);
    expect(text['link'], isNull);
    expect(text['未知'], isNull);
    final plain = jsonDecode(jsonEncode(text)) as Map;
    expect(plain, equals(text));
    expect(plain['selected'], isTrue);
    expect(plain['emphasisUnderline'], {'color': 123});
    expect(() => text['value'] = '修改', throwsUnsupportedError);
    expect(text.clear, throwsUnsupportedError);
    expect(() => text.remove('value'), throwsUnsupportedError);
    expect(() => (text['bounds'] as Map)['left'] = 100, throwsUnsupportedError);
    expect(() => elements[0] = <String, dynamic>{}, throwsUnsupportedError);
  });
  test('只解析当前契约，缺少样式或缓冲即失败，跨页共享批次存储', () {
    for (final field in ['textStyles', 'glyphs']) {
      final missing = compactReply()..remove(field);
      expect(
        () => ReaderLayoutReply.decode(jsonEncode(missing)),
        throwsFormatException,
      );
    }
    final value = compactReply();
    value['pages'].add({
      'elements': [0],
    });
    final pages = ReaderLayoutReply.decode(jsonEncode(value)).pages;
    final first = pages[0]['elements'] as ReaderElementDataList;
    final second = pages[1]['elements'] as ReaderElementDataList;
    expect(identical(first.columns, second.columns), true);
    expect(
      identical(
        (first.first as ReaderGlyphData).columns,
        (second.first as ReaderGlyphData).columns,
      ),
      true,
    );
  });
  test('行文字、通用元素和选区字形共享数据，坐标变换不改写绝对几何', () {
    final reply = ReaderLayoutReply.decode(jsonEncode(compactReply()));
    final data = reply.pages.single['elements'] as ReaderElementDataList;
    final textOnly = ReaderElementDataList.decode([0], data.columns);
    final elements = ReaderLayoutElementList(textOnly);
    final row = ReaderLineElements(elements, [0]);
    final words = ReaderLineWords(row);
    final glyphs = ReaderLineGlyphs(row, 9, const Offset(4, 2));
    expect(identical(words.elements, glyphs.elements), true);
    expect(identical(row.elements, elements), true);
    expect(words.join(), '😀');
    expect(glyphs.single.start, 0);
    expect(glyphs.single.end, 2);
    expect(glyphs.single.bounds, const Rect.fromLTRB(0, 0, 18, 24));
    expect(glyphs.single.baseline, 19);
    expect(elements.single.bounds, const Rect.fromLTRB(4, 2, 22, 26));
    expect(() => words[0] = '改写', throwsUnsupportedError);
    expect(() => glyphs.clear(), throwsUnsupportedError);
  });
  test('创建尚未返回时取消仍释放实际会话，后续推送拒绝', () async {
    final transport = _Transport();
    final session = ReaderLayoutSession(config: {}, transport: transport);
    final stopped = session.cancel();
    transport.beginResult.complete(transport.reply());
    await stopped;
    await session.cancel();
    await expectLater(session.push([]), throwsA(isA<ReaderLayoutCancelled>()));
    expect(transport.calls, ['begin', 'cancel']);
  });
  test('切章取消在途推送，不返回迟到页面', () async {
    final transport = _Transport()..deferPush = true;
    final session = ReaderLayoutSession(config: {}, transport: transport);
    transport.beginResult.complete(transport.reply());
    final pushed = session.push([]);
    final rejected = expectLater(pushed, throwsA(isA<ReaderLayoutCancelled>()));
    await Future<void>.delayed(Duration.zero);
    await session.cancel();
    transport.pending.single.complete(
      transport.reply(
        pages: [
          {'旧页面': true},
        ],
      ),
    );
    await rejected;
    expect(session.closed, isTrue);
  });
  test('批次串行执行，finish 返回末页并阻止继续推送', () async {
    final transport = _Transport()..deferPush = true;
    final session = ReaderLayoutSession(config: {}, transport: transport);
    transport.beginResult.complete(transport.reply());
    final first = session.push([]);
    final second = session.push([]);
    final finish = session.finish();
    await Future<void>.delayed(Duration.zero);
    expect(transport.pending, hasLength(1));
    transport.pending[0].complete(transport.reply());
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(transport.pending, hasLength(2));
    transport.pending[1].complete(transport.reply());
    await second;
    expect((await finish).pages.single['最后一页'], isTrue);
    await expectLater(session.push([]), throwsA(isA<ReaderLayoutCancelled>()));
    expect(transport.calls, ['begin', 'push', 'push', 'finish']);
  });
  test('协议版本和会话身份不匹配时硬失败并释放', () async {
    final transport = _Transport()..deferPush = true;
    final session = ReaderLayoutSession(config: {}, transport: transport);
    transport.beginResult.complete(transport.reply());
    final pushed = session.push([]);
    final rejected = expectLater(pushed, throwsFormatException);
    await Future<void>.delayed(Duration.zero);
    transport.pending.single.complete(transport.reply(id: '其他会话'));
    await rejected;
    expect(transport.calls.last, 'cancel');
    expect(
      () => ReaderLayoutReply.decode('{"schemaVersion":2}'),
      throwsFormatException,
    );
  });
  test('类型化调用记录调用总耗时与 Rust 计时，JSON 编解码计时为零', () async {
    final transport = _Transport();
    final diagnostics = ReaderLayoutDiagnostics();
    final session = ReaderLayoutSession(
      config: {},
      transport: transport,
      diagnostics: diagnostics,
    );
    transport.beginResult.complete(transport.reply());
    await session.push([]);
    await session.finish();
    expect(diagnostics.ffiCalls, 3);
    expect(diagnostics.rustMicroseconds, 30);
    expect(diagnostics.measurementCalls, 0);
    expect(diagnostics.encodingMicroseconds, 0);
    expect(diagnostics.decodingMicroseconds, 0);
  });
}
