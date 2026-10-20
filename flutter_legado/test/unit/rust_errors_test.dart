import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/ffi.dart' show BridgeError;
import 'package:flutter_legado/src/data/bridge/rust_errors.dart';
import 'package:flutter_legado/src/data/repositories/mock_bookmark_repository.dart';
import 'package:flutter_legado/src/domain/errors/app_exception.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_legado/src/utils/error_message.dart';

void main() {
  const original = BridgeError(message: '正文获取失败');
  final stack = StackTrace.fromString('原始调用位置');

  test('同步桥接错误保留消息、操作、原因及抛出堆栈', () {
    try {
      rustCall<void>(
        () => Error.throwWithStackTrace(original, stack),
        operation: '读取正文',
      );
      fail('必须抛错');
    } catch (error, thrownStack) {
      expect(error, isA<AppException>());
      final value = error as AppException;
      expect(value.message, original.message);
      expect(value.operation, '读取正文');
      expect(value.cause, same(original));
      expect(value.sourceStackTrace.toString(), stack.toString());
      expect(thrownStack.toString(), stack.toString());
      expect(errorMessage(value), '正文获取失败');
    }
  });

  test('Future同时转换同步起调失败和异步错误', () async {
    for (final action in <Future<int> Function()>[
      () => throw original,
      () => Future<int>.error(original, stack),
    ]) {
      await expectLater(
        rustFuture(action),
        throwsA(
          isA<AppException>()
              .having((e) => e.message, '消息', original.message)
              .having((e) => e.cause, '原因', same(original)),
        ),
      );
    }
    expect(await rustFuture(() async => 42), 42);
  });

  test('普通错误、领域错误和取消标记均不改变身份或堆栈', () async {
    final cancel = Object();
    for (final error in [
      StateError('失败'),
      const AppException('领域失败'),
      cancel,
    ]) {
      expect(() => rustCall<void>(() => throw error), throwsA(same(error)));
      try {
        await rustFuture<void>(() => Future.error(error, stack));
        fail('必须抛错');
      } catch (actual, actualStack) {
        expect(actual, same(error));
        expect(actualStack.toString(), stack.toString());
      }
    }
  });

  test('Stream保留值、错误、完成顺序及原始错误堆栈', () async {
    final input = StreamController<int>();
    final values = <Object>[];
    final done = Completer<void>();
    rustStream(() => input.stream).listen(
      values.add,
      onError: (Object error, StackTrace trace) {
        values.add(error);
        expect(trace.toString(), stack.toString());
      },
      onDone: done.complete,
    );
    input.add(1);
    input.addError(original, stack);
    input.add(2);
    await input.close();
    await done.future;
    expect(values[0], 1);
    expect(
      values[1],
      isA<AppException>().having((e) => e.cause, '原始错误', same(original)),
    );
    expect(values[2], 2);
  });

  test('Stream启动同步错误仍转换，普通流错误保持身份', () async {
    expect(
      () => rustStream<int>(() => throw original),
      throwsA(isA<AppException>()),
    );
    final error = StateError('非桥接失败');
    await expectLater(
      rustStream(() => Stream<int>.error(error, stack)),
      emitsError(same(error)),
    );
  });

  test('Stream暂停、恢复和退订继续传递，取消只执行一次', () async {
    var pauses = 0, resumes = 0, cancels = 0;
    final input = StreamController<int>(
      onPause: () => pauses++,
      onResume: () => resumes++,
      onCancel: () => cancels++,
    );
    final subscription = rustStream(() => input.stream).listen((_) {});
    subscription.pause();
    expect(pauses, 1);
    subscription.resume();
    expect(resumes, 1);
    await subscription.cancel();
    await subscription.cancel();
    expect(cancels, 1);
    await input.close();
  });

  test('广播流保留广播属性与多订阅，错误逐订阅转换且不重复包装', () async {
    final input = StreamController<int>.broadcast(sync: true);
    final stream = rustStream(() => input.stream);
    expect(stream.isBroadcast, isTrue);
    final first = <Object>[], second = <Object>[];
    final a = stream.listen(first.add, onError: (Object e) => first.add(e));
    final b = stream.listen(second.add, onError: (Object e) => second.add(e));
    const mapped = AppException('已转换');
    input.add(1);
    input.addError(mapped, stack);
    expect(first, [1, same(mapped)]);
    expect(second, [1, same(mapped)]);
    await a.cancel();
    await b.cancel();
    await input.close();
  });

  test('空白桥接消息通过领域展示回退，普通错误仍使用原字符串', () {
    final value = mapRustError(const BridgeError(message: '  '), stack);
    expect(errorMessage(value), kUnknownErrorMessage);
    expect(
      errorMessage(const FormatException('格式错误')),
      'FormatException: 格式错误',
    );
  });

  test('实际Mock仓储失败仍保留普通异常及原有展示文本', () async {
    final repository = MockBookmarkRepository();
    try {
      await repository.updateBookmark(const Bookmark(id: -1));
      fail('不存在的书签必须失败');
    } catch (error) {
      expect(error, isA<StateError>());
      expect(errorMessage(error), 'Bad state: 书签不存在: -1');
    }
    expect(await repository.getAllBookmarks(), isEmpty);
  });
}
