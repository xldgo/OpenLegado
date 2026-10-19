import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/bridge/task_dto.dart';
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/data/services/rust_webview_bridge_service.dart';
import 'package:flutter_legado/src/domain/models/webview_request.dart';

void main() {
  test('真实FRB传递Header、最终URL、空正文及拒绝未知回传', () async {
    final path =
        Platform.environment['LEGADO_FFI_DLL'] ??
        '${Directory.current.parent.path}/rust/target/debug/legado_ffi.dll';
    await NativeRustRuntime(libraryResolver: () => ExternalLibrary.open(path))
        .initialize();
    const service = RustWebViewBridgeService();
    final received = <WebViewRequest>[];
    final submitted = Completer<bool>();
    final sub = service.webviewRequestStream().listen((request) async {
      if (request.action == 'cancel') return;
      received.add(request);
      try {
        final accepted = await service.completeWebviewRequest(
          request.key,
          WebViewExecutionResult(
            result: '',
            finalUrl: 'https://final.test/',
          ),
        );
        if (!submitted.isCompleted) submitted.complete(accepted);
      } catch (error, stack) {
        if (!submitted.isCompleted) submitted.completeError(error, stack);
      }
    });
    addTearDown(sub.cancel);
    // FRB流在Rust侧异步注册；注册前的明确失败可重试，不假设固定延迟即可就绪。
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    String result;
    do {
      result = await bridge
          .jsEval(
            script: r'''
        var r=java.connect('https://start.test/,{"webView":true,"headers":{"X-Test":"wire"}}');
        JSON.stringify([r.code(),r.body(),r.raw().request().url().toString()]);
      ''',
          )
          .timeout(const Duration(seconds: 5));
      if (received.isNotEmpty) break;
      expect(result, contains('WebView执行订阅'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } while (DateTime.now().isBefore(deadline));
    expect(await submitted.future.timeout(const Duration(seconds: 1)), isTrue);
    expect(jsonDecode(result), [200, '', 'https://final.test/']);
    expect(received.single.headers, containsPair('X-Test', 'wire'));
    expect(
      await bridge.webviewComplete(
        key: 'unknown',
        response: const WebViewResponseDto(
          result: '',
          finalUrl: '',
          cookies: {},
        ),
      ),
      isFalse,
    );
    expect(await bridge.webviewPending(), isEmpty);
  }, skip: !Platform.isWindows);
}
