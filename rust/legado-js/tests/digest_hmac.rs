//! 固定JDK向量与真实QuickJS桥接，运行时不依赖JVM或网络。
#![cfg(feature = "quickjs")]
use legado_js::{
    engine::{JsEngine, QuickJsEngine},
    sandbox::SandboxConfig,
};
fn engine() -> QuickJsEngine {
    QuickJsEngine::new(
        SandboxConfig::default()
            .with_allow_script_run(true)
            .with_memory_limit(64 * 1024 * 1024),
    )
    .unwrap()
}
fn check(code: &str) {
    assert_eq!(engine().eval(code).unwrap(), "true", "{code}");
}
#[test]
fn jdk_vectors_match_hex_and_base64_on_both_entrypoints() {
    let code = format!(
        r#"var vectors={}; [java,globalThis].every(function(j){{return vectors.every(function(v){{
  return String(j.digestHex(v.data,v.algorithm))===v.digestHex && j.digestBase64Str(v.data,v.algorithm)===v.digestBase64 &&
    j.hmacHex(v.data,'Hmac'+v.algorithm.replace(/-/g,''),v.key)===v.hmacHex && j.hmacBase64(v.data,v.algorithm,v.key)===v.hmacBase64;
 }})}})"#,
        include_str!("fixtures/digest_vectors.json")
    );
    check(&code);
}
#[test]
fn uppercase_hmac_entrypoints_preserve_confirmed_aliases() {
    check(
        r#"[java,globalThis].every(function(j){return typeof j.HMacHex==='function' &&
  j.HMacHex('hello','HMAC-SHA1','key')==='b34ceac4516ff23a143e61d79d0fa7a4fbe5f266' &&
  j.HMacBase64('hello','HMAC-SHA1','key')===j.hmacBase64('hello','SHA1','key') &&
  j.HMacHex('hello','HmacSHA384','key')===j.hmacHex('hello','SHA384','key')})"#,
    );
}
#[test]
fn invalid_algorithms_null_and_empty_keys_throw_instead_of_producing_text() {
    check(
        r#"[java,globalThis].every(function(j){
  var calls=[()=>j.digestHex('hello','bad'),()=>j.digestBase64Str('hello','bad'),
   ()=>j.hmacHex('hello','SHA256',''),()=>j.hmacBase64('hello','SHA256',''),()=>j.hmacMd5('hello',''),()=>j.hmacSha256('hello',''),
   ()=>j.digestHex(null,'MD5'),()=>j.digestHex('hello',null),()=>j.digestBase64Str(null,'MD5'),
   ()=>j.hmacHex('hello','SHA256',null),()=>j.HMacBase64(null,'HmacSHA256','key')];
  return calls.every(function(f){try{f();return false}catch(e){return true}}) &&
    String(j.digestHex('hello','MD5'))==='5d41402abc4b2a76b9719d911017c592';
 })"#,
    );
}
#[test]
fn packages_digest_catalog_and_execution_share_the_new_algorithms() {
    check(
        r#"['SHA-224','SHA-384'].every(function(algorithm){
   var md=Packages.java.security.MessageDigest.getInstance(algorithm);
   var bytes=java.strToBytes('hello');
   md.update(bytes.subarray(0,2));
   var first=md.digest(bytes.subarray(2));
   return java.base64EncodeBytes(first)===java.digestBase64Str('hello',algorithm) &&
      java.base64EncodeBytes(md.digest())===java.digestBase64Str('',algorithm);
 })"#,
    );
}
#[test]
fn invalid_digest_views_are_rejected_without_resetting_accumulated_state() {
    check(
        r#"(function(){
  var buffer=new ArrayBuffer(2), detached=new Uint8Array(buffer); buffer.transfer();
  var md=Packages.java.security.MessageDigest.getInstance('SHA-256');md.update(java.strToBytes('hello'));
  var calls=[()=>java.messageDigestDigest('SHA-256',detached),()=>md.update(detached),()=>md.digest(detached),()=>md.update(null)];
  return calls.every(function(f){try{f();return false}catch(e){return true}}) &&
    java.base64EncodeBytes(md.digest())===java.digestBase64Str('hello','SHA-256');
 })()"#,
    );
}

#[test]
fn string_conversion_and_java_result_methods_are_preserved() {
    check(
        r#"(function(){
  var expected='5d41402abc4b2a76b9719d911017c592', result=java.digestHex('hello','MD5');
  return result.length()===32 && String(result.substring(0,4))==='5d41' && result.getBytes().length===32 &&
   String(result)===expected && typeof digestHex('hello','MD5')==='string' &&
   [java,globalThis].every(function(j){return String(j.digestHex(undefined,'MD5'))==='5e543256c480ac577d30f76f9120eb74' &&
    String(j.digestHex(['a','b'],'MD5'))==='b345e1dc09f20fdefdea469f09167892' &&
    String(j.digestHex('hello','SHA'))===String(j.digestHex('hello','SHA-1'))});
 })()"#,
    );
}

#[test]
fn conversion_exceptions_propagate_and_name_policies_remain_explicit() {
    check(
        r#"(function(){
  var marker=new Error('转换失败'), bad={toString:function(){throw marker}};
  return [java,globalThis].every(function(j){
    var calls=[()=>j.digestHex(bad,'MD5'),()=>j.digestHex('hello',bad),()=>j.hmacHex('hello','SHA256',bad)];
    return calls.every(function(f){try{f();return false}catch(e){return e===marker}}) &&
      [()=>j.digestHex('hello','SHA 256'),()=>j.hmacHex('hello','HmacSHA3-256','key')].every(function(f){try{f();return false}catch(e){return true}});
  }) && java.base64EncodeBytes(Packages.java.security.MessageDigest.getInstance('SHA 256').digest(java.strToBytes('hello')))===java.digestBase64Str('hello','SHA256');
 })()"#,
    );
}

#[test]
fn byte_ranges_empty_views_and_out_of_bounds_failures_are_distinguished() {
    check(
        r#"(function(){
  var buffer=new ArrayBuffer(4,{maxByteLength:8}), invalid=new Uint8Array(buffer,2,2);buffer.resize(1);
  var md=Packages.java.security.MessageDigest.getInstance('SHA-256');md.update(java.strToBytes('hello'));
  var calls=[()=>java.messageDigestDigest('SHA-256',invalid),()=>md.update(invalid),()=>md.digest(invalid),()=>md.digest(null)];
  if(!calls.every(function(f){try{f();return false}catch(e){return true}}))return false;
  var valid=new Int8Array([0,104,101,108,108,111,0]).subarray(1,6);
  return java.base64EncodeBytes(md.digest())===java.digestBase64Str('hello','SHA256') &&
   java.base64EncodeBytes(java.messageDigestDigest('SHA256',valid))===java.digestBase64Str('hello','SHA256') &&
   java.base64EncodeBytes(java.messageDigestDigest('SHA256',new Uint8Array(0)))===java.digestBase64Str('','SHA256');
 })()"#,
    );
}
