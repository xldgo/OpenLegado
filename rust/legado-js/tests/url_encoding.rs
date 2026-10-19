//! URL表单、原生URI及字符集重载的真实QuickJS回归。
#![cfg(feature = "quickjs")]
use legado_js::{
    engine::{JsEngine, QuickJsEngine},
    sandbox::SandboxConfig,
};
fn check(code: &str) {
    let engine = QuickJsEngine::new(
        SandboxConfig::default()
            .with_allow_script_run(true)
            .with_memory_limit(64 * 1024 * 1024),
    )
    .unwrap();
    assert_eq!(engine.eval(code).unwrap(), "true", "{code}");
}
#[test]
fn java_form_encoding_has_its_own_safe_characters() {
    check(
        r#"java.encodeURI("a b+c-_.!*~'()/?:@&=+$,#") === 'a+b%2Bc-_.%21*%7E%27%28%29%2F%3F%3A%40%26%3D%2B%24%2C%23'"#,
    );
}
#[test]
fn global_uri_functions_keep_native_reserved_and_surrogate_behavior() {
    check(
        r#"(function(){
  if(encodeURI('https://a/b?x=a b+c#z')!=='https://a/b?x=a%20b+c#z' ||
     encodeURIComponent('a b+c')!=='a%20b%2Bc' || encodeURI===java.encodeURI) return false;
  var bad=[()=>encodeURI(String.fromCharCode(0xd800)),()=>encodeURIComponent(String.fromCharCode(0xd800))];
  return bad.every(function(f){try{f();return false}catch(e){return e instanceof URIError}}) &&
    decodeURI('https://a/b?x=a%20b+c#z')==='https://a/b?x=a b+c#z' && decodeURIComponent('%2B')==='+';
 })()"#,
    );
}
#[test]
fn form_encoding_resets_multibyte_encoder_at_each_unsafe_run() {
    check(
        r#"java.encodeURI('中文A汉字 B','GBK')==='%D6%D0%CE%C4A%BA%BA%D7%D6+B' &&
 java.encodeURI('中文A汉字 B','UTF-16')==='%FE%FF%4E%2D%65%87A%FE%FF%6C%49%5B%57+B' &&
 java.encodeURI('中文A汉字 B','UTF-16LE')==='%2D%4E%87%65A%49%6C%57%5B+B' &&
 java.encodeURI('😀','GBK')==='%3F' && java.encodeURI('é','ISO-8859-1')==='%E9'"#,
    );
}
#[test]
fn charset_omission_null_and_failure_have_distinct_results() {
    check(
        r#"(function(){
  if(java.encodeURI(['a','b'])!=='a%2Cb' || java.encodeURI(undefined)!=='undefined' ||
     java.encodeURI('a',undefined)!=='' || java.encodeURI('中','not-a-charset')!=='' ||
     java.encodeURI('a',false)!=='' || java.encodeURI('a','utf-8 ')!=='' || java.encodeURI('a',['UTF-8'])!=='a') return false;
  var bad=[()=>java.encodeURI(null),()=>java.encodeURI('a',null),()=>java.encodeURI()];
  return bad.every(function(f){try{f();return false}catch(e){return true}}) && java.encodeURI('a b')==='a+b';
 })()"#,
    );
}
#[test]
fn form_aliases_decode_plus_and_reject_bad_percent_without_poisoning_vm() {
    check(
        r#"[java,globalThis].every(function(j){
  if(j.urlencode('a b+c-_.!*')!=='a+b%2Bc-_.%21*' || j.urldecode('a+b%2Bc')!=='a b+c' ||
     j.urldecode('%E4%B8%AD')!=='中' || j.urldecode('%FF')!=='\ufffd') return false;
  return ['%','%2','%GG','% E4'].every(function(s){try{j.urldecode(s);return false}catch(e){return true}}) &&
    j.urldecode(j.urlencode('中文 +😀'))==='中文 +😀';
 })"#,
    );
}

#[test]
fn registration_preserves_native_function_identity_even_when_repeated() {
    let runtime = rquickjs::Runtime::new().unwrap();
    let context = rquickjs::Context::full(&runtime).unwrap();
    context.with(|ctx| {
   ctx.eval::<(),_>("globalThis.originalUris=[encodeURI,encodeURIComponent,decodeURI,decodeURIComponent]").unwrap();
   for _ in 0..2 {
     legado_js::host_api::register_all(&ctx,&SandboxConfig::default()).unwrap();
     assert!(ctx.eval::<bool,_>("originalUris.every((f,i)=>f===[encodeURI,encodeURIComponent,decodeURI,decodeURIComponent][i]) && java.encodeURIComponent===encodeURIComponent").unwrap());
   }
 });
}
#[test]
fn parameter_coercion_failures_are_not_swallowed_by_encoding_fallback() {
    check(
        r#"(function(){
  var broken={toString:function(){throw new Error('coercion sentinel')}};
  var calls=[()=>java.encodeURI(broken),()=>java.encodeURI('a',broken),()=>java.urlencode(broken),()=>java.urldecode(broken)];
  return calls.every(function(f){try{f();return false}catch(e){return String(e).includes('coercion sentinel')}}) &&
    java.encodeURI('x y')==='x+y' && java.urldecode('%EF%BB%BF')==='\ufeff' &&
    encodeURIComponent(undefined)==='undefined' && java.encodeURIComponent(null)==='null';
 })()"#,
    );
}
