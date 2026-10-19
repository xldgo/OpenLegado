import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/data/bridge/entity_dto_mapping.dart';
import 'package:flutter_legado/src/data/services/rust_webview_bridge_service.dart';
import 'package:flutter_legado/src/models/book_source.dart';
import 'package:flutter_legado/src/domain/models/webview_request.dart';
import 'package:flutter_legado/src/platform/webview_page_bridge.dart';

void main() {
  setUpAll(() async {
    if (!Platform.isWindows) return;
    final path =
        Platform.environment['LEGADO_FFI_DLL'] ??
        '${Directory.current.parent.path}/rust/target/debug/legado_ffi.dll';
    await NativeRustRuntime(libraryResolver: () => ExternalLibrary.open(path))
        .initialize();
  });
  test('真实FRB页内调用共享原来源/缓存，结束后拒绝调用', () async {
    const service = RustWebViewBridgeService();
    final seen = <String>[];
    final accepted = Completer<void>();
    final sub = service.webviewRequestStream().listen((request) async {
      if (request.action == 'cancel') return;
      seen.add(request.key);
      try {
        Future<String> call(
          WebViewPageTarget target,
          String method,
          List<String?> args,
        ) => service.pageCall(
          request.key,
          WebViewPageCall(target: target, method: method, args: args),
        );
        expect(
          jsonDecode(await call(WebViewPageTarget.source, 'getKey', [])),
          'https://page-host.test',
        );
        expect(
          jsonDecode(
            await call(WebViewPageTarget.source, 'put', ['k', 'shared']),
          ),
          'shared',
        );
        expect(
          jsonDecode(await call(WebViewPageTarget.java, 'get', ['k'])),
          'shared',
        );
        expect(
          jsonDecode(
            await call(WebViewPageTarget.cache, 'putMemory', [
              'page-host-memory',
              'cached',
            ]),
          ),
          null,
        );
        expect(
          jsonDecode(
            await call(WebViewPageTarget.cache, 'getFromMemory', [
              'page-host-memory',
            ]),
          ),
          'cached',
        );
        await expectLater(
          call(WebViewPageTarget.java, 'eval', ['1+1']),
          throwsA(anything),
        );
        expect(
          await service.completeWebviewRequest(
            request.key,
            WebViewExecutionResult(result: '完成'),
          ),
          isTrue,
        );
        accepted.complete();
      } catch (error, stack) {
        accepted.completeError(error, stack);
        await service.cancelWebviewRequest(request.key);
      }
    });
    addTearDown(sub.cancel);
    const source = BookSource(
      bookSourceUrl: 'https://page-host.test',
      bookSourceName: '夹具',
      loginUi: '{"version":2}',
      loginUrl: "function loginUi(state){return {rows:[{name:java.webView('<html>fixture</html>','https://page.test/','document.title'),type:'text'}]};}",
    );
    // 确认流注册：未注册时保留动作载荷；只重试该明确前置状态。
    String output = '';
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    do {
      output = await bridge
          .sourceLoginUiV2(source: bookSourceToDto(source), stateJson: '{}')
          .timeout(const Duration(seconds: 5));
      if (seen.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    } while (DateTime.now().isBefore(deadline));
    await accepted.future.timeout(const Duration(seconds: 2));
    expect(jsonDecode(output)['rows'][0]['name'], '完成');
    expect(
      await bridge.jsEval(script: "get('v_https://page-host.test_k')"),
      'shared',
    );
    expect(
      await bridge.jsEval(script: "cache.getFromMemory('page-host-memory')"),
      'cached',
    );
    await expectLater(
      service.pageCall(
        seen.single,
        WebViewPageCall(
          target: WebViewPageTarget.source,
          method: 'put',
          args: ['k', 'late'],
        ),
      ),
      throwsA(anything),
    );
  }, skip: !Platform.isWindows);
  test('平台共用的真实JS门面保留同步返回、空值、抛错和后台request语义', () async {
    final script = webViewPageScript('token');
    final result = await bridge.jsEval(
      script:
          r"""
      globalThis.window=globalThis;
      var calls=[];
      window.prompt=function(token,payload){
        var c=JSON.parse(payload);calls.push(c);
        if(c.method==='get')return JSON.stringify({value:''});
        if(c.method==='putVariable')return JSON.stringify({value:null});
        if(c.method==='ajax')return JSON.stringify({error:'网络失败'});
        return JSON.stringify({value:'ok'});
      };
    """ +
          script +
          r"""
      var originalSource=window.source;
      window.source={overwritten:true};
    """ +
          script +
          r"""
      if(window.source!==originalSource)throw new Error('重复安装改变门面实例');
      var results=[source.get('empty'),source.putVariable(null)===undefined,java.request('x',[], 'id')===undefined];
      try{java.ajax('https://fail.test');}catch(e){results.push(String(e));}
      try{source.unknown();}catch(e){results.push(String(e));}
      results.push(calls);JSON.stringify(results);
    """,
    );
    final value = jsonDecode(result) as List;
    expect(value.take(3), ['', true, true]);
    expect(value[3], contains('网络失败'));
    expect(value[4], contains('未支持的后台source.unknown'));
    expect(value[5], hasLength(3));
    expect(value[5][1]['args'], [null]);
  }, skip: !Platform.isWindows);
}
