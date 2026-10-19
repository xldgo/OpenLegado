//! 编码重载与双入口的真实QuickJS回归，不依赖JVM或外部网络。
#![cfg(feature = "quickjs")]
use legado_js::{
    engine::{JsEngine, QuickJsEngine},
    sandbox::SandboxConfig,
};
fn check(script: &str) {
    let engine = QuickJsEngine::new(
        SandboxConfig::default()
            .with_allow_script_run(true)
            .with_memory_limit(64 * 1024 * 1024),
    )
    .unwrap();
    assert_eq!(engine.eval(script).unwrap(), "true", "{script}");
}
#[test]
fn base64_text_overloads_keep_hutool_leniency() {
    check(
        r#"[java,globalThis].every(function(j){
      return j.base64Decode('5Lit5paH') === '中文' &&
        j.base64Decode('1tDOxA','GBK') === '中文' &&
        j.base64Decode('Z=g=') === 'f' && j.base64Decode('a') === '' &&
        j.base64Decode('_w==') === '\ufffd' && j.base64Decode(null) === '' &&
        j.base64Decoder('Zg') === 'f';
    })"#,
    );
}
#[test]
fn base64_android_padding_and_errors_are_catchable() {
    check(
        r#"[java,globalThis].every(function(j){
      var a = j.base64DecodeToByteArray(' Z#h ');
      if (!(a instanceof Uint8Array) || a[0] !== 102 || j.base64Decode('Zg',0) !== 'f' ||
          j.base64DecodeToByteArray(null) !== null || j.base64DecodeToByteArray(' \n') !== null) return false;
      var bad=[()=>j.base64Decode('Zg=',0),()=>j.base64Decode('Zg','not-a-charset'),
        ()=>j.base64Decode('Zg',null),()=>j.base64Decode('Z~g=='),()=>j.base64DecodeToByteArray('Zg===')];
      return bad.every(function(f){try{f();return false}catch(e){return true}}) && j.base64Decode('Zg') === 'f';
    })"#,
    );
}
#[test]
fn base64_encode_flags_and_package_forwarding() {
    check(
        r#"[java,globalThis].every(function(j){
      return j.base64Encode('f') === 'Zg==' && j.base64Encode('f',0) === 'Zg==\n' &&
        j.base64Encode('f',1) === 'Zg\n' && j.base64Encode('f',4) === 'Zg==\r\n' &&
        j.base64Encode('f',3) === 'Zg' && j.base64Encode('',0) === '' &&
        j.base64EncodeBytes(new Uint8Array([255]),10) === '_w==';
    }) && Packages.android.util.Base64.encodeToString(new Uint8Array([255]),11) === '_w'"#,
    );
}
#[test]
fn hex_empty_and_invalid_utf8_have_java_results() {
    check(
        r#"[java,globalThis].every(function(j){
      var empty=j.hexDecodeToByteArray('');
      return empty instanceof Uint8Array && empty.length === 0 && j.hexDecodeToString('ff') === '\ufffd' &&
        j.hexDecode('e4b8ad') === '中' && j.hexEncodeToString('中文') === 'e4b8ade69687';
    })"#,
    );
}
#[test]
fn base64_wraps_at_76_and_preserves_byte_view_before_coercion() {
    check(
        r#"(function(){
      var text='x'.repeat(58), result=java.base64Encode(text,0);
      var lines=result.split('\n');
      var bytes=new Uint8Array([0,255,1]).subarray(1,2);
      var flags={toString:function(){bytes[0]=0; return '10'}};
      return lines.length===3 && lines[0].length===76 && lines[1].length===4 &&
        java.base64EncodeBytes(bytes,flags)==='_w==';
    })()"#,
    );
}

#[test]
fn invalid_hex_throws_and_vm_can_continue() {
    check(
        r#"[java,globalThis].every(function(j){
      var bad=[()=>j.hexDecode('not hex'),()=>j.hexDecodeToString('f'),()=>j.hexDecodeToByteArray(' '),
        ()=>j.hexDecode(null),()=>j.base64Encode(null),()=>j.base64Encode('a',null)];
      return bad.every(function(f){try{f();return false}catch(e){return true}}) && j.hexDecode('61')==='a';
    })"#,
    );
}

#[test]
fn overload_dispatch_and_strict_flags_match_rhino() {
    check(
        r#"(function(){
      if(java.base64Decode('1tDOxA',['GBK'])!=='中文' || java.base64Decode(null,'bad-charset')!=='') return false;
      if(java.base64Encode('f','3')!=='Zg' || java.base64DecodeToByteArray('Zg','0')[0]!==102) return false;
      var bad=[()=>java.base64Decode('Zg','0'),()=>java.base64Decode('Zg',undefined),
        ()=>java.base64Decode(null,0),()=>java.base64Decode('Zg',NaN),()=>java.base64Decode('Zg',2147483648),
        ()=>java.base64DecodeToByteArray('Zg',null),()=>java.base64DecodeToByteArray('Zg',undefined),
        ()=>java.base64Encode('f',true),()=>java.base64Encode('f',undefined)];
      return bad.every(function(f){try{f();return false}catch(e){return true}});
    })()"#,
    );
}
#[test]
fn binary_encoding_checks_detached_and_signed_byte_views() {
    check(
        r#"(function(){
      if(java.base64EncodeBytes(new Int8Array([-1]),10)!=='_w==' || java.base64EncodeBytes([-1],10)!=='_w==') return false;
      var buffer=new ArrayBuffer(1), array=new Uint8Array(buffer); buffer.transfer();
      try{java.base64EncodeBytes(array);return false}catch(e){}
      var bad=[()=>java.hexDecodeToByteArray(null),()=>java.hexDecodeToByteArray('0g'),()=>java.hexDecodeToByteArray('a')];
      return bad.every(function(f){try{f();return false}catch(e){return true}}) && java.base64Decode('Zg')==='f';
    })()"#,
    );
}
