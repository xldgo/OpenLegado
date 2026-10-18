import 'dart:async';

import '../../bridge/ffi.dart' show BridgeError;
import '../../domain/errors/app_exception.dart';

/// 只转换已知桥接异常；取消、领域异常和普通异常保持原有身份。— Codex + Bridge
Object mapRustError(Object error, StackTrace stack, {String? operation}) =>
    error is BridgeError
    ? AppException(
        error.message,
        operation: operation,
        cause: error,
        sourceStackTrace: stack,
      )
    : error;

T rustCall<T>(T Function() action, {String? operation}) {
  try {
    return action();
  } catch (error, stack) {
    final mapped = mapRustError(error, stack, operation: operation);
    if (identical(mapped, error)) rethrow;
    Error.throwWithStackTrace(mapped, stack);
  }
}

Future<T> rustFuture<T>(
  Future<T> Function() action, {
  String? operation,
}) async {
  try {
    return await action();
  } catch (error, stack) {
    final mapped = mapRustError(error, stack, operation: operation);
    if (identical(mapped, error)) rethrow;
    Error.throwWithStackTrace(mapped, stack);
  }
}

Stream<T> rustStream<T>(Stream<T> Function() start, {String? operation}) =>
    rustCall(start, operation: operation).transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (Object error, StackTrace stack, EventSink<T> sink) => sink
            .addError(mapRustError(error, stack, operation: operation), stack),
      ),
    );
