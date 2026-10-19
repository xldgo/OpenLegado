import 'dart:convert';

import '../domain/models/webview_request.dart';

/// 两种平台入口共用参数解析和结果信封，不在平台内镜像来源或缓存。— Codex + Bridge
class WebViewPageBridge {
  WebViewPageBridge(this.invokeHost);
  final Future<String> Function(WebViewPageCall call) invokeHost;

  Future<String> invoke(String payload) async {
    try {
      final value = jsonDecode(payload);
      if (value is! Map<String, dynamic> ||
          value.length != 3 ||
          !value.containsKey('target') ||
          !value.containsKey('method') ||
          !value.containsKey('args')) {
        throw const FormatException('页内调用必须包含target、method、args');
      }
      final target = WebViewPageTarget.values
          .where((t) => t.name == value['target'])
          .firstOrNull;
      final method = value['method'];
      final args = value['args'];
      if (target == null ||
          method is! String ||
          method.trim().isEmpty ||
          args is! List ||
          args.any((a) => a != null && a is! String)) {
        throw const FormatException('页内调用字段类型不正确');
      }
      final result = await invokeHost(
        WebViewPageCall(
          target: target,
          method: method,
          args: args.cast<String?>(),
        ),
      );
      return jsonEncode({'value': jsonDecode(result)});
    } catch (error) {
      return jsonEncode({'error': error.toString()});
    }
  }
}

/// prompt回调可异步访问Rust，但网页得到同步返回值；不改成快照或延迟写回。
String webViewPageScript(String token) =>
    """
(function(){
  var installed=window.__legadoPageHost;
  if(installed && installed.token===${jsonEncode(token)}) {
    window.source=installed.source;window.cache=installed.cache;window.java=installed.java;return;
  }
  function call(target, method, args) {
    var raw = window.prompt(${jsonEncode(token)}, JSON.stringify({
      target:target, method:method,
      args:Array.prototype.map.call(args,function(v){return v==null?null:String(v);})
    }));
    if(raw===null) throw new Error('页内调用已取消或宿主不可用');
    var reply=JSON.parse(raw);
    if(reply.error) throw new Error(reply.error);
    if(!Object.prototype.hasOwnProperty.call(reply,'value')) throw new Error('页内宿主缺少结果');
    return reply.value;
  }
  function facade(target, names, voids) {
    var object={};
    names.forEach(function(name){object[name]=function(){var v=call(target,name,arguments);if(voids.indexOf(name)<0)return v;};});
    return new Proxy(object,{get:function(obj,name){
      if(name in obj || typeof name!=='string')return obj[name];
      return function(){throw new Error('未支持的后台'+target+'.'+name+'方法');};
    }});
  }
  var source=facade('source',['getKey','get','put','getVariable','putVariable','getLoginHeader','getLoginInfo','putLoginInfo','removeLoginInfo','login'],['putVariable','removeLoginInfo','login']);
  var cache=facade('cache',['get','put','putMemory','getFromMemory','deleteMemory','delete','putFile','getFile'],['put','putMemory','deleteMemory','delete','putFile']);
  var java=facade('java',['get','put','ajax','connect','getString','getStringList','head','post'],[]);
  java.getSource=function(){return source;};
  // 上游后台没有Activity，request不会执行或伪造Promise完成事件。
  java.request=function(){};
  window.source=source;window.cache=cache;window.java=java;
  window.__legadoPageHost={token:${jsonEncode(token)},source:source,cache:cache,java:java};
})();
""";
