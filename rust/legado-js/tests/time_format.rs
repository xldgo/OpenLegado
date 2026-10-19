//! Java时间数字格式与现有本地扩展的真实QuickJS回归。
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
fn java_time_patterns_and_quoted_literals_are_formatted() {
    check(
        r#"[java,globalThis].every(function(j){return   j.timeFormatUTC(1704067200123,'yyyy-MM-dd HH:mm:ss.SSS',0)==='2024-01-01 00:00:00.123' &&
  j.timeFormatUTC(123,"yyyy-MM-dd'T'HH:mm:ss.SSS 'o''clock'",0)==="1970-01-01T00:00:00.123 o'clock" &&
  j.timeFormatUTC(123,"''yyyy''",0)==="'1970'" && j.timeFormatUTC(0,'',0)==='';
 })"#,
    );
}
#[test]
fn negative_milliseconds_and_fractional_offsets_are_kept() {
    check(
        r#"[java,globalThis].every(function(j){return   j.timeFormatUTC(-1,'yyyy-MM-dd HH:mm:ss.SSS',0)==='1969-12-31 23:59:59.999' &&
  j.timeFormatUTC(-1001,'yyyy-MM-dd HH:mm:ss.SSS',0)==='1969-12-31 23:59:58.999' &&
  j.timeFormatUTC(-1,'yyyy-MM-dd HH:mm:ss.SSS',1)==='1970-01-01 00:00:00.000' &&
  j.timeFormatUTC(-1,'yyyy-MM-dd HH:mm:ss.SSS',-1)==='1969-12-31 23:59:59.998' &&
  j.timeFormat(-1)===j.timeFormat(-1000);
 })"#,
    );
}
#[test]
fn java_numeric_widths_hours_and_offsets_do_not_use_chrono_tokens() {
    check(
        r#"[java,globalThis].every(function(j){return   j.timeFormatUTC(123,'y yy yyy yyyy M MM L LL d dd D DDD F u',0)==='1970 70 1970 1970 1 01 1 01 1 01 1 001 1 4' &&
  j.timeFormatUTC(123,'H HH k kk K KK h hh m mm s ss S SS SSS SSSS',0)==='0 00 24 24 0 00 12 12 0 00 0 00 123 123 123 0123' &&
  j.timeFormatUTC(0,'X XX XXX Z',19800000)==='+05 +0530 +05:30 +0530' &&
  j.timeFormatUTC(0,'X XX XXX Z',-19800000)==='-05 -0530 -05:30 -0530' &&
  j.timeFormatUTC(0,'X XX XXX Z',-1)==='+00 +0000 +00:00 +0000';
 })"#,
    );
}
#[test]
fn bad_java_patterns_and_null_are_catchable_and_vm_survives() {
    check(
        r#"[java,globalThis].every(function(j){
  var calls=[()=>j.timeFormatUTC(0,'qq',0),()=>j.timeFormatUTC(0,"yyyy'",0),
    ()=>j.timeFormatUTC(0,'XXXX',0),()=>j.timeFormatUTC(0,null,0),()=>j.timeFormatUTC(0,undefined,0)];
  return calls.every(function(f){try{f();return false}catch(e){return true}}) &&
    j.timeFormatUTC(0,'yyyy-MM-dd%',0)==='1970-01-01%';
 })"#,
    );
}
#[test]
fn chrono_extensions_keep_their_existing_grammar_and_invalid_formats_do_not_panic() {
    check(
        r#"java.parseTime('2024-01-01 00:00:00','%Y-%m-%d %H:%M:%S')===1704067200000 &&
  java.parseTime('bad','%Y')===-1 && java.formatTime(0,'yyyy')==='yyyy' &&
  java.formatTime(0,'%Q').startsWith('[ERROR]') && java.timeFormatUTC(0,'yyyy',0)==='1970'"#,
    );
}

#[test]
fn large_raw_offsets_and_numeric_coercion_keep_java_millisecond_semantics() {
    check(
        r#"[java,globalThis].every(function(j){return   j.timeFormatUTC(-1,'yyyy-MM-dd HH:mm:ss.SSS X XX XXX Z',2147483647)==='1970-01-25 20:31:23.646 +596 +59631 +596:31 +59631' &&
  j.timeFormatUTC(-1,'yyyy-MM-dd HH:mm:ss.SSS X XX XXX Z',-2147483648)==='1969-12-07 03:28:36.351 -596 -59631 -596:31 -59631' &&
  j.timeFormatUTC('0',['yyyyMMddHHmmss'],'1000')==='19700101000001';
 })"#,
    );
}
#[test]
fn out_of_range_time_and_coercion_errors_do_not_return_success_or_poison_vm() {
    check(
        r#"[java,globalThis].every(function(j){
  var broken={toString:function(){throw new Error('time coercion sentinel')}};
  var calls=[()=>j.timeFormatUTC(1e18,'yyyy',0),()=>j.timeFormatUTC(0,broken,0),
    ()=>j.timeFormatUTC(null,'yyyy',0),()=>j.timeFormatUTC(0,'yyyy',null),()=>j.timeFormatUTC(0)];
  return calls.every(function(f){try{f();return false}catch(e){return true}}) && j.timeFormatUTC(0,'yyyy',0)==='1970';
 })"#,
    );
}

#[test]
fn locale_dependent_patterns_are_explicitly_unsupported_in_numeric_scope() {
    check(
        r#"['MMMM','EEE','a','YYYY-ww','z','G'].every(function(pattern){
   try{java.timeFormatUTC(0,pattern,0);return false}catch(e){return String(e).includes('Locale')}
 }) && java.timeFormatUTC(0,"'星期' u",0)==='星期 4'"#,
    );
}
