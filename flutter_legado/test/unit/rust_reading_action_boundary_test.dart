import 'dart:async';

import 'package:flutter_legado/src/bridge/source_tools_dto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/services/rust_reading_content_service.dart';
import 'package:flutter_legado/src/data/services/rust_source_action_service.dart';
import 'package:flutter_legado/src/domain/models/source_action_result.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const content = RustReadingContentService();
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('繁简和章级参数原样交给Rust，试算返回与权威状态分离', () async {
    when(() => bridge.crateFfiFfiReaderSetChineseConvert(convertType: 2))
        .thenAnswer((_) async {});
    when(() => bridge.crateFfiFfiReaderGetChineseConvert())
        .thenAnswer((_) async => 2);
    when(
      () => bridge.crateFfiFfiReaderToggleSameTitleRemoved(
        bookUrl: 'stable-book',
        chapterIndex: 3,
        enable: false,
      ),
    ).thenAnswer((_) async {});
    when(
      () => bridge.crateFfiFfiReaderGetSameTitleRemoved(
        bookUrl: 'stable-book',
        chapterIndex: 3,
      ),
    ).thenAnswer((_) async => false);
    when(
      () => bridge.crateFfiFfiReaderCanRemoveSameTitle(
        chapterTitle: '第三章',
        rawContent: '第三章\n正文',
      ),
    ).thenAnswer((_) async => true);
    await content.setChineseConvertType(2);
    expect(await content.getChineseConvertType(), 2);
    await content.toggleSameTitleRemoved('stable-book', 3, false);
    expect(await content.getSameTitleRemoved('stable-book', 3), isFalse);
    expect(await content.canRemoveSameTitle('第三章', '第三章\n正文'), isTrue);
    verify(
      () => bridge.crateFfiFfiReaderToggleSameTitleRemoved(
        bookUrl: 'stable-book',
        chapterIndex: 3,
        enable: false,
      ),
    ).called(1);
  });
  test('正文设置读取、写入和试算失败向上传播', () async {
    final error = StateError('数据库不可用');
    when(() => bridge.crateFfiFfiReaderSetChineseConvert(convertType: 2))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiReaderGetChineseConvert()).thenThrow(error);
    when(
      () => bridge.crateFfiFfiReaderToggleSameTitleRemoved(
        bookUrl: 'b',
        chapterIndex: 1,
        enable: true,
      ),
    ).thenThrow(error);
    when(
      () => bridge.crateFfiFfiReaderGetSameTitleRemoved(
        bookUrl: 'b',
        chapterIndex: 1,
      ),
    ).thenThrow(error);
    when(
      () => bridge.crateFfiFfiReaderCanRemoveSameTitle(
        chapterTitle: 't',
        rawContent: 'c',
      ),
    ).thenThrow(error);
    await expectLater(
      () => content.setChineseConvertType(2),
      throwsA(same(error)),
    );
    await expectLater(content.getChineseConvertType, throwsA(same(error)));
    await expectLater(
      () => content.toggleSameTitleRemoved('b', 1, true),
      throwsA(same(error)),
    );
    await expectLater(
      () => content.getSameTitleRemoved('b', 1),
      throwsA(same(error)),
    );
    await expectLater(
      () => content.canRemoveSameTitle('t', 'c'),
      throwsA(same(error)),
    );
  });
  for (final (raw, kind) in [
    (ChapterPurchaseKindDto.url, ChapterPurchaseKind.url),
    (ChapterPurchaseKindDto.success, ChapterPurchaseKind.success),
    (ChapterPurchaseKindDto.none, ChapterPurchaseKind.none),
  ]) {
    test('购买返回$raw保留结果与章级身份', () async {
      when(
        () => bridge.crateFfiFfiChapterPayAction(bookUrl: 'b', chapterIndex: 7),
      ).thenAnswer((_) async => ChapterPurchaseDto(kind: raw, value: '原始返回'));
      final service = RustSourceActionService(
        dispatchActions: (_) async => fail('购买不回放无关回调'),
      );
      final result = await service.chapterPayAction(
        bookUrl: 'b',
        chapterIndex: 7,
      );
      expect(result.kind, kind);
      expect(result.value, '原始返回');
    });
  }
  test('回调先等待平台动作全部回放，再返回接管结果，动作只回放一次', () async {
    final calls = <String>[];
    final gate = Completer<void>();
    when(
      () => bridge.crateFfiFfiSourceCallBackBtn(
        event: 'clickShareBook',
        bookUrl: 'stable',
        chapterIndex: 4,
        result: 'share',
        bookType: 2,
      ),
    ).thenAnswer((_) async {
      calls.add('native');
      return const SourceCallbackDto(
        invoked: true,
        jsTrue: true,
        raw: 'true',
        actionsJson:
            '[{"action":"copyText","text":"回调内容","extra":{"keep":true}}]',
      );
    });
    final service = RustSourceActionService(
      dispatchActions: (actions) async {
        expect(actions, [
          {
            'action': 'copyText',
            'text': '回调内容',
            'extra': {'keep': true},
          },
        ]);
        calls.add('dispatch');
        await gate.future;
        calls.add('dispatched');
      },
    );
    var completed = false;
    final response = service
        .sourceCallBackBtn(
          event: 'clickShareBook',
          bookUrl: 'stable',
          chapterIndex: 4,
          result: 'share',
          bookType: 2,
        )
        .then((value) {
          completed = true;
          return value;
        });
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['native', 'dispatch']);
    expect(completed, isFalse);
    gate.complete();
    final result = await response;
    expect(result.handled, isTrue);
    expect(result.raw, 'true');
    expect(result.actions, hasLength(1));
    expect(calls, ['native', 'dispatch', 'dispatched']);
  });
  test('未接管也先回放动作，布尔判断保留Rust结果', () async {
    var dispatched = 0;
    when(
      () => bridge.crateFfiFfiSourceCallBackBtn(
        event: 'e',
        bookUrl: 'b',
        bookType: 0,
      ),
    ).thenAnswer(
      (_) async => const SourceCallbackDto(
        invoked: true,
        jsTrue: false,
        raw: 'false',
        actionsJson: '[{"action":"toast"}]',
      ),
    );
    final service = RustSourceActionService(
      dispatchActions: (_) async {
        dispatched++;
      },
    );
    final result = await service.sourceCallBackBtn(event: 'e', bookUrl: 'b');
    expect(result.handled, isFalse);
    expect(result.invoked, isTrue);
    expect(dispatched, 1);
  });
  test('坏回调不回放动作，原生和回放器异常不伪造默认结果', () async {
    var dispatched = 0;
    final service = RustSourceActionService(
      dispatchActions: (_) async {
        dispatched++;
        throw StateError('回放失败');
      },
    );
    when(
      () => bridge.crateFfiFfiSourceCallBackBtn(
        event: 'bad',
        bookUrl: 'b',
        bookType: 0,
      ),
    ).thenAnswer(
      (_) async => const SourceCallbackDto(
        invoked: true,
        jsTrue: false,
        raw: 'false',
        actionsJson: '{}',
      ),
    );
    await expectLater(
      service.sourceCallBackBtn(event: 'bad', bookUrl: 'b'),
      throwsFormatException,
    );
    expect(dispatched, 0);
    when(
      () => bridge.crateFfiFfiSourceCallBackBtn(
        event: 'throw',
        bookUrl: 'b',
        bookType: 0,
      ),
    ).thenAnswer(
      (_) async => const SourceCallbackDto(
        invoked: true,
        jsTrue: true,
        raw: 'true',
        actionsJson: '[{}]',
      ),
    );
    await expectLater(
      service.sourceCallBackBtn(event: 'throw', bookUrl: 'b'),
      throwsStateError,
    );
    final error = StateError('购买失败');
    when(
      () => bridge.crateFfiFfiChapterPayAction(bookUrl: 'b', chapterIndex: 1),
    ).thenThrow(error);
    await expectLater(
      service.chapterPayAction(bookUrl: 'b', chapterIndex: 1),
      throwsA(same(error)),
    );
  });
}
