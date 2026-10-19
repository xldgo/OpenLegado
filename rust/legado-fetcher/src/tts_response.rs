//! HTTP TTS 二进制 Response JS 适配，正文不经过有损字符串转换。
use legado_core::{LegadoError, LegadoResult};
use legado_net::LegadoRawResponse;
use legado_parser::JsExecutor;
use std::collections::HashMap;
pub(crate) fn evaluate_tts_response(
    executor: &dyn JsExecutor,
    script: &str,
    response: LegadoRawResponse,
) -> LegadoResult<LegadoRawResponse> {
    evaluate_tts_response_with_headers(executor, script, response, &HashMap::new())
}

pub(crate) fn evaluate_tts_response_with_headers(
    executor: &dyn JsExecutor,
    script: &str,
    response: LegadoRawResponse,
    headers: &HashMap<String, String>,
) -> LegadoResult<LegadoRawResponse> {
    let value = serde_json::json!({"status":response.status,"headers":response.headers,"body":response.body,"url":response.url});
    let code = serde_json::to_string(script)?;
    let header_json = serde_json::to_string(headers)?;
    let wrapped = format!(
        "{RESPONSE_JS}\nglobalThis.__ttsRequestHeaders=__ttsMap({header_json});globalThis.result=__ttsResponse({value});\neval({code})"
    );
    let output = executor
        .execute_js(&wrapped)
        .map_err(LegadoError::JsEngine)?;
    let value: serde_json::Value = serde_json::from_str(&output)
        .map_err(|_| LegadoError::JsEngine("loginCheckJs 必须返回响应对象".into()))?;
    if !value.is_object() || value.get("status").is_none() || value.get("body").is_none() {
        return Err(LegadoError::JsEngine(
            "loginCheckJs 必须返回响应对象".into(),
        ));
    }
    Ok(LegadoRawResponse {
        raw_summary: response.raw_summary,
        status: serde_json::from_value(value["status"].clone())?,
        headers: serde_json::from_value(value["headers"].clone())?,
        body: serde_json::from_value(value["body"].clone())?,
        url: serde_json::from_value(value["url"].clone())?,
    })
}

const RESPONSE_JS: &str = r#"
function __ttsResponse(data) {
  function header(name) {for(var k in data.headers)if(k.toLowerCase()===String(name).toLowerCase())return data.headers[k];return null;}
  var response={
    code:function(){return data.status;},
    header:header,
    headers:function(name){return arguments.length ? (header(name)==null?[]:[header(name)]) : __ttsMap(data.headers);},
    request:function(){return {url:function(){return data.url;}};},
    body:function(){return {bytes:function(){return data.body;},byteStream:function(){return data.body;},string:function(){return java.bytesToStr(data.body,'utf-8');}};},
    newBuilder:function(){
      var next=JSON.parse(JSON.stringify(data));
      var builder={
        code:function(v){next.status=v;return builder;},
        header:function(k,v){for(var old in next.headers)if(old.toLowerCase()===String(k).toLowerCase())delete next.headers[old];next.headers[k]=String(v);return builder;},
        body:function(v){next.body=Array.isArray(v)?v:(v&&typeof v.bytes==='function'?v.bytes():java.strToBytes(String(v),'utf-8'));return builder;},
        build:function(){return __ttsResponse(next);}
      };
      return builder;
    },
    toJSON:function(){return data;}
  };
  return response;
}
"#;
