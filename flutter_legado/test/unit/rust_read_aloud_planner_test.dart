import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/bridge/read_aloud_dto.dart';
import 'package:flutter_legado/src/bridge/media_dto.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' show BridgeError;
import 'package:flutter_legado/src/data/services/rust_read_aloud_planner.dart';
import 'package:flutter_legado/src/domain/models/read_aloud_content.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';

class _Api extends Mock implements RustLibApi {}

void main() {
  late _Api api;
  const planner = RustReadAloudPlanner();
  setUpAll(() => registerFallbackValue(<ReadAloudRangeDto>[]));
  setUp(() {
    api = _Api();
    RustLib.initMock(api: api);
  });
  tearDown(RustLib.dispose);
  test('真实页界和模式按类型传入，返回UTF-16范围映射原文及段落语义', () async {
    when(
      () => api.crateFfiReadAloudPlan(
        content: '甲😀乙',
        mode: ReadAloudSplitModeDto.page,
        symbols: '。',
        pages: any(named: 'pages'),
      ),
    ).thenAnswer(
      (_) async => [
        ReadAloudUnitDto(
          start: BigInt.from(1),
          end: BigInt.from(3),
          sourceParagraphIndex: BigInt.from(4),
          isParagraphEnd: false,
        ),
      ],
    );
    final units = await planner.plan(
      '甲😀乙',
      mode: ReadAloudSplitMode.page,
      symbols: '。',
      pages: [(start: 0, end: 4)],
    );
    expect(
      (
        units.single.start,
        units.single.end,
        units.single.text,
        units.single.sourceParagraphIndex,
        units.single.isParagraphEnd,
      ),
      (1, 3, '😀', 4, false),
    );
    final sent =
        verify(
              () => api.crateFfiReadAloudPlan(
                content: '甲😀乙',
                mode: ReadAloudSplitModeDto.page,
                symbols: '。',
                pages: captureAny(named: 'pages'),
              ),
            ).captured.single
            as List<ReadAloudRangeDto>;
    expect((sent.single.start.toInt(), sent.single.end.toInt()), (0, 4));
  });
  test('批量请求保持输入顺序与相对范围，桥接失败向上传递', () async {
    when(
      () => api.crateFfiCloudTtsPartition(
        provider: CloudTtsProviderDto.mimo,
        texts: ['甲😀乙', 'second'],
      ),
    ).thenAnswer(
      (_) async => [
        SpeechPartitionDto(
          ranges: [
            ReadAloudRangeDto(start: BigInt.from(1), end: BigInt.from(3)),
          ],
        ),
        SpeechPartitionDto(
          ranges: [
            ReadAloudRangeDto(start: BigInt.from(0), end: BigInt.from(6)),
          ],
        ),
      ],
    );
    final result = await planner.partition('mimo', ['甲😀乙', 'second']);
    expect(result, [
      [(start: 1, text: '😀')],
      [(start: 0, text: 'second')],
    ]);
    when(
      () => api.crateFfiCloudTtsPartition(
        provider: CloudTtsProviderDto.mimo,
        texts: ['失败'],
      ),
    ).thenThrow(const BridgeError(message: '分片失败'));
    await expectLater(
      planner.partition('mimo', ['失败']),
      throwsA(
        isA<AppException>().having(
          (e) => e.toString(),
          '错误原因',
          contains('分片失败'),
        ),
      ),
    );
  });
}
