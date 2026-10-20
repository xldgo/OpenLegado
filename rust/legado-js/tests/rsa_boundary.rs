//! 自生成测试密钥及显式OAEP参数的JDK固定向量，不依赖运行时JVM。
#![cfg(feature = "quickjs")]
use legado_js::{
    engine::{JsEngine, QuickJsEngine},
    sandbox::SandboxConfig,
};
fn check(script: &str) {
    let e = QuickJsEngine::new(
        SandboxConfig::default()
            .with_allow_script_run(true)
            .with_memory_limit(64 * 1024 * 1024),
    )
    .unwrap();
    let code = format!(
        "var v={};function bytes(x){{return x?java.base64DecodeToByteArray(x,2):new Uint8Array(0)}};function hx(x){{return Array.prototype.map.call(x,b=>b.toString(16).padStart(2,'0')).join('')}};{script}",
        include_str!("fixtures/rsa_vectors.json")
    );
    assert_eq!(e.eval(&code).unwrap(), "true", "{script}");
}
#[test]
fn rsa_der_keys_and_ciphertexts_match_jdk_including_empty_and_segmented_data() {
    check(
        r#"[java,globalThis].every(function(j){return v.ciphers.every(function(c){
  var r=j.createAsymmetricCrypto(c.transformation);r.setPublicKey(bytes(v.publicKey)).setPrivateKey(bytes(v.privateKey));
  var direction=c.direction!=='public',data=bytes(c.data),ct=bytes(c.cipher);
  return java.base64EncodeBytes(r.decrypt(ct,direction))===c.data &&
    r.encrypt(data,!direction).length===ct.length &&
    (c.direction!=='private'||java.base64EncodeBytes(r.encrypt(data,false))===c.cipher);
 })})"#,
    );
}
#[test]
fn existing_base64_pem_keys_and_hex_ciphertext_extensions_are_preserved() {
    check(
        r#"(function(){var r=java.createAsymmetricCrypto('RSA');
  r.setPublicKey('-----BEGIN PUBLIC KEY-----\n'+v.publicKey.match(/.{1,64}/g).join('\n')+'\n-----END PUBLIC KEY-----').setPrivateKey(v.privateKey);
  var c=v.ciphers[0],ct=bytes(c.cipher);
  return r.decryptStr(hx(ct),false)==='hello中文😀' && r.decryptStr(c.cipher,false)==='hello中文😀';
 })()"#,
    );
}
#[test]
fn signing_byte_ranges_match_all_six_independent_jdk_vectors() {
    check(
        r#"[java,globalThis].every(function(j){return v.signatures.every(function(s){
  var sign=j.createSign(s.algorithm).setPrivateKey(bytes(v.privateKey)).setPublicKey(bytes(v.publicKey));
  var raw=bytes(s.data),padded=new Int8Array(raw.length+2);padded.set(raw,1);var range=padded.subarray(1,1+raw.length);
  var output=sign.sign(range);
  return java.base64EncodeBytes(output)===s.signature && sign.signHex(Array.from(range))===hx(output) &&
    sign.verify(raw,bytes(s.signature)) && !sign.verify(java.strToBytes('changed'),output);
 })})"#,
    );
}
#[test]
fn malformed_transformations_and_missing_sign_keys_are_errors() {
    check(
        r#"(function(){var cases=['RSA/CBC/PKCS1Padding','RSA/ECB','RSA/ECB/PKCS1Padding/extra','RSA/ECB/OAEPWithSHA3-256AndMGF1Padding','RSA//PKCS1Padding'];
  return cases.every(function(t){try{java.createAsymmetricCrypto(t);return false}catch(e){return true}}) &&
   [()=>java.createAsymmetricCrypto(null),()=>java.createSign('SHA256withRSA').sign('hello'),()=>java.createSign('SHA256withRSA').verify('hello',new Uint8Array(256))].every(function(f){try{f();return false}catch(e){return true}});
 })()"#,
    );
}
#[test]
fn empty_messages_and_nullable_direction_have_real_rsa_semantics() {
    check(
        r#"(function(){var r=java.createAsymmetricCrypto('RSA').setPublicKey(v.publicKey).setPrivateKey(v.privateKey);
  var data=java.strToBytes('hello');var ct=r.encrypt(data,null);
  return ct.length===256 && r.decryptStr(ct,true)==='hello' && r.encrypt('',true).length===256 &&
   [()=>r.encrypt(data,1),()=>r.encrypt(data,'false')].every(function(f){try{f();return false}catch(e){return true}});
 })()"#,
    );
}
#[test]
fn invalid_key_update_keeps_previous_key_and_short_type1_padding_is_rejected() {
    check(
        r#"(function(){var r=java.createAsymmetricCrypto('RSA').setPublicKey(v.publicKey).setPrivateKey(v.privateKey),ok=0;
  try{r.setPrivateKey(new Uint8Array([1,2,3]))}catch(e){ok++}
  try{r.decrypt(bytes(v.invalidType1Cipher),true)}catch(e){ok++}
  return ok===2 && r.decryptStr(bytes(v.ciphers[0].cipher),false)==='hello中文😀';
 })()"#,
    );
}
#[test]
fn packages_specs_factory_and_signature_reset_follow_real_sessions() {
    check(
        r#"(function(){var P=Packages.java.security,pri=bytes(v.privateKey),pub=bytes(v.publicKey);
  var spec=P.spec.PKCS8EncodedKeySpec(pri);pri.fill(0);spec.getEncoded().fill(0);
  var factory=P.KeyFactory.getInstance('RSA'),key=factory.generatePrivate(spec),pk=factory.generatePublic(new P.spec.X509EncodedKeySpec(pub));
  var s=P.Signature.getInstance('SHA256withRSA'),data=bytes(v.signatures[3].data);s.initSign(key);s.update(data);
  var a=s.sign();s.update(data);var b=s.sign();s.initVerify(pk);s.update(data);var good=s.verify(a);s.update(java.strToBytes('bad'));var bad=s.verify(b);
  return java.base64EncodeBytes(a)===v.signatures[3].signature && hx(a)===hx(b) && good && !bad;
 })()"#,
    );
}
#[test]
fn packages_signature_invalid_updates_and_reinitialization_are_isolated() {
    check(
        r#"(function(){var P=Packages.java.security,F=P.KeyFactory.getInstance('RSA');
  var key=F.generatePrivate(P.spec.PKCS8EncodedKeySpec(bytes(v.privateKey))),s=P.Signature.getInstance('SHA256withRSA'),ok=0;
  try{s.update(new Uint8Array(0))}catch(e){ok++}
  s.initSign(key);s.update(bytes(v.signatures[3].data));var b=new ArrayBuffer(3),dead=new Uint8Array(b);b.transfer();
  try{s.update(dead)}catch(e){ok++}try{s.update(null)}catch(e){ok++}
  var result=java.base64EncodeBytes(s.sign())===v.signatures[3].signature;
  try{s.initSign(null)}catch(e){ok++}try{s.sign()}catch(e){ok++}
  return ok===5 && result;
 })()"#,
    );
}

#[test]
fn keys_accept_signed_offset_views_and_invalid_views_leave_valid_keys_intact() {
    check(
        r#"(function(){
      var raw=bytes(v.privateKey), padded=new Int8Array(raw.length+4);padded.set(raw,2);
      var key=padded.subarray(2,2+raw.length),r=java.createAsymmetricCrypto('RSA');
      r.setPrivateKey(Array.from(key)).setPublicKey(bytes(v.publicKey));padded.fill(0);
      var b=new ArrayBuffer(4),dead=new Int8Array(b);b.transfer();var failed=false;
      try{r.setPrivateKey(dead)}catch(e){failed=true}
      var s=java.createSign('SHA256withRSA').setPrivateKey(v.privateKey).setPublicKey(v.publicKey);
      var data=bytes(v.signatures[3].data),sig=bytes(v.signatures[3].signature);
      return failed && r.decryptStr(bytes(v.ciphers[0].cipher),false)==='hello中文😀' &&
       s.verify(data,hx(sig)) && s.verify(data,v.signatures[3].signature);
    })()"#,
    );
}

#[test]
fn packages_signature_modes_incremental_updates_and_failed_verify_are_reusable() {
    check(
        r#"(function(){var P=Packages.java.security,F=P.KeyFactory.getInstance('RSA'),
      pri=F.generatePrivate(P.spec.PKCS8EncodedKeySpec(bytes(v.privateKey))),pub=F.generatePublic(P.spec.X509EncodedKeySpec(bytes(v.publicKey))),
      s=P.Signature.getInstance('SHA256withRSA'),data=bytes(v.signatures[3].data),sig=bytes(v.signatures[3].signature),ok=0;
      s.initSign(pri);s.update(data.subarray(0,3));s.update(Array.from(new Int8Array(data.buffer).subarray(3)));
      try{s.verify(sig)}catch(e){ok++}
      var a=s.sign();s.initVerify(pub);s.update(data);var b=new ArrayBuffer(2),dead=new Uint8Array(b);b.transfer();
      try{s.verify(dead)}catch(e){ok++}
      var valid=s.verify(sig);s.update(data);var bad=s.verify(new Uint8Array(256));
      try{s.sign()}catch(e){ok++}
      s.update(data);return ok===3 && valid && !bad && s.verify(sig) && hx(a)===hx(sig);
    })()"#,
    );
}

#[test]
fn key_factory_rejects_invalid_der_when_generating_and_does_not_create_fake_keys() {
    check(
        r#"(function(){var P=Packages.java.security,F=P.KeyFactory.getInstance('RSA'),calls=[
      ()=>F.generatePrivate(P.spec.PKCS8EncodedKeySpec(new Uint8Array([1,2,3]))),
      ()=>F.generatePublic(P.spec.X509EncodedKeySpec(new Uint8Array([1,2,3]))),
      ()=>F.generatePrivate(P.spec.X509EncodedKeySpec(bytes(v.publicKey))),
      ()=>new P.spec.PKCS8EncodedKeySpec(null),()=>java.createSign(null),
      ()=>java.createSign('SHA256withRSA').setPrivateKey(null)];
      return calls.every(function(f){try{f();return false}catch(e){return true}});
    })()"#,
    );
}
