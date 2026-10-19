//! 使用JDK固定密文验证真实QuickJS入口；测试运行不依赖JVM。
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
    assert_eq!(engine.eval(&format!("function bytesHex(x){{return Array.prototype.map.call(x,function(b){{return b.toString(16).padStart(2,'0')}}).join('')}};{script}")).unwrap(), "true", "{script}");
}
#[test]
fn object_ciphertexts_match_independent_jdk_vectors() {
    check(&format!(
        r#"var vectors={}; [java,globalThis].every(function(j){{return vectors.every(function(v){{
      var c=j.createSymmetricCrypto(v.transformation,java.hexDecodeToByteArray(v.key),v.iv?java.hexDecodeToByteArray(v.iv):null);
      var data=java.hexDecodeToByteArray(v.data);return bytesHex(c.encrypt(data))===v.cipher &&
       c.encryptHex(data)===v.cipher && c.encryptBase64(data)===v.base64 &&
       bytesHex(c.decrypt(java.hexDecodeToByteArray(v.cipher)))===v.data;
    }})}})"#,
        include_str!("fixtures/symmetric_vectors.json")
    ));
}
#[test]
fn hex_base64_defaults_and_charset_share_the_object_boundary() {
    check(
        r#"(function(){var k='0123456789abcdef', c=java.createSymmetricCrypto('AES',k);
      var hex=c.encryptHex('hello'), b64=c.encryptBase64('hello');
      return c.decryptStr(hex)==='hello' && c.decryptStr(b64.replace(/=/g,''))==='hello' &&
       c.encryptBase64('中文','GBK')===c.encryptBase64(java.strToBytes('中文','GBK')) &&
       c.encryptBase64('中文','UTF-16')===c.encryptBase64(java.strToBytes('中文','UTF-16'));
    })()"#,
    );
}
#[test]
fn cipher_modes_snapshot_inputs_and_reset_between_final_calls() {
    check(
        r#"(function(){var C=Packages.javax.crypto.Cipher,S=Packages.javax.crypto.spec;
      var key=java.strToBytes('0123456789abcdef'), iv=java.strToBytes('fedcba9876543210');
      var sk=new S.SecretKeySpec(key,'AES'), spec=new S.IvParameterSpec(iv);key.fill(0);iv.fill(0);
      var c=C.getInstance('AES/CBC/PKCS5Padding');c.init(C.ENCRYPT_MODE,sk,spec);
      sk.key.fill(0);spec.iv.fill(0);
      var data=java.strToBytes('hello'), a=c.doFinal(data), b=c.doFinal(data);
      var ref=java.createSymmetricCrypto('AES/CBC/PKCS5Padding','0123456789abcdef','fedcba9876543210');
      var d=C.getInstance('AES/CBC/PKCS5Padding');
      d.init(C.DECRYPT_MODE,new S.SecretKeySpec(java.strToBytes('0123456789abcdef'),'AES'),new S.IvParameterSpec(c.getIV()));
      var copy=c.getIV();copy.fill(0);
      return bytesHex(a)===ref.encryptHex('hello') && bytesHex(a)===bytesHex(b) &&
       java.bytesToStr(d.doFinal(a))==='hello' && java.bytesToStr(c.getIV())==='fedcba9876543210';
    })()"#,
    );
}
#[test]
fn invalid_strings_modes_keys_and_padding_throw_without_success_text() {
    check(
        r#"[java,globalThis].every(function(j){var calls=[
      ()=>j.aesEncrypt('x','bad'),()=>j.aesDecrypt('x','bad'),()=>j.desEncrypt('x','bad'),()=>j.desDecrypt('x','bad'),
      ()=>j.tripleDESEncodeBase64Str('x','0123456789abcdef','OFB','NoPadding','00000000'),
      ()=>j.aesBase64DecodeToString('!','bad','AES/CBC/PKCS5Padding',''),
      ()=>j.aesEncrypt(null,'0123456789abcdef'),()=>j.createSymmetricCrypto('AES/ECB/BadPadding','0123456789abcdef'),
      ()=>j.createSymmetricCrypto('DES/OFB/PKCS5Padding','12345678')];
      return calls.every(function(f){try{f();return false}catch(e){return true}}) && j.aesDecrypt(j.aesEncrypt('hello','0123456789abcdef'),'0123456789abcdef')==='hello';
    })"#,
    );
}
#[test]
fn invalid_cipher_bytes_do_not_become_empty_data() {
    check(
        r#"(function(){var buf=new ArrayBuffer(4),dead=new Uint8Array(buf);buf.transfer();
      var c=java.createSymmetricCrypto('AES/ECB/NoPadding','0123456789abcdef');
      var calls=[()=>c.encrypt(dead),()=>c.decrypt(dead),()=>java.aesDecryptBytes(dead,java.strToBytes('0123456789abcdef'),null,'AES/ECB/NoPadding')];
      return calls.every(function(f){try{f();return false}catch(e){return true}}) && c.encrypt(new Uint8Array(0)).length===0;
    })()"#,
    );
}
#[test]
fn set_iv_is_chainable_copies_bytes_and_accepts_signed_ranges() {
    check(
        r#"(function(){var c=java.createSymmetricCrypto('AES/CBC/PKCS5Padding','0123456789abcdef');
      var iv=java.strToBytes('fedcba9876543210'), same=c.setIv(iv)===c;iv.fill(0);
      var plain=new Int8Array([0,104,101,108,108,111,0]).subarray(1,6);
      var reference=java.createSymmetricCrypto('AES/CBC/PKCS5Padding','0123456789abcdef','fedcba9876543210');
      return same && c.encryptHex(plain)===reference.encryptHex([104,101,108,108,111]) && c.decryptStr(c.encrypt(plain))==='hello';
    })()"#,
    );
}
#[test]
fn uninitialized_or_failed_initialization_cannot_run_cipher() {
    check(
        r#"(function(){var C=Packages.javax.crypto.Cipher,S=Packages.javax.crypto.spec,c=C.getInstance('AES/CBC/PKCS5Padding'),ok=0;
      try{c.doFinal(new Uint8Array(0))}catch(e){ok++}
      try{c.init(99,new S.SecretKeySpec(java.strToBytes('0123456789abcdef'),'AES'))}catch(e){ok++}
      try{c.init(C.DECRYPT_MODE,new S.SecretKeySpec(java.strToBytes('0123456789abcdef'),'AES'))}catch(e){ok++}
      try{c.init(C.ENCRYPT_MODE,new S.SecretKeySpec(java.strToBytes('0123456789abcdef'),'DES'))}catch(e){ok++}
      try{c.doFinal(new Uint8Array(0))}catch(e){ok++}
      c.init(C.ENCRYPT_MODE,new S.SecretKeySpec(java.strToBytes('0123456789abcdef'),'AES'));
      return ok===5 && c.getIV().length===16 && c.doFinal(new Uint8Array(0)).length===16;
    })()"#,
    );
}

#[test]
fn random_keys_iv_generation_and_failed_calls_keep_objects_usable() {
    check(
        r#"(function(){
      var c=java.createSymmetricCrypto('AES',null), ct=c.encrypt('hello');
      var C=Packages.javax.crypto.Cipher,S=Packages.javax.crypto.spec,k=new S.SecretKeySpec(java.strToBytes('0123456789abcdef'),'AES');
      var en=C.getInstance('AES/CBC/PKCS5Padding');en.init(C.ENCRYPT_MODE,k);
      var de=C.getInstance('AES/CBC/PKCS5Padding');de.init(C.DECRYPT_MODE,k,new S.IvParameterSpec(en.getIV()));
      var restored=java.bytesToStr(de.doFinal(en.doFinal(java.strToBytes('hello'))));
      var invalid=[()=>java.rc4Encrypt('x',''),()=>java.rc4Decrypt('eA==',''),
        ()=>java.createSymmetricCrypto('RC4',''),()=>java.createSymmetricCrypto('AES',''),
        ()=>java.createSymmetricCrypto('AES/CBC/PKCS5Padding','0123456789abcdef').decryptStr('00'),
        ()=>en.init(C.ENCRYPT_MODE,new S.SecretKeySpec(java.strToBytes('bad'),'AES'))];
      var all=invalid.every(function(f){try{f();return false}catch(e){return true}});
      en.init(C.ENCRYPT_MODE,k,new S.IvParameterSpec(java.strToBytes('fedcba9876543210')));
      return all && c.decryptStr(ct)==='hello' && restored==='hello' && en.doFinal(java.strToBytes('hello')).length===16;
    })()"#,
    );
}

#[test]
fn native_bytes_are_owned_before_transformation_can_reenter_js() {
    check(
        r#"(function(){var key=java.strToBytes('0123456789abcdef'),c=java.createSymmetricCrypto('AES/ECB/NoPadding',key);
      var ct=c.encrypt('0123456789abcdef'), buf=ct.buffer,kbuf=key.buffer;
      var t={toString:function(){buf.transfer();kbuf.transfer();return 'AES/ECB/NoPadding'}};
      return java.bytesToStr(java.aesDecryptBytes(ct,key,null,t))==='0123456789abcdef';
    })()"#,
    );
}

#[test]
fn key_normalization_empty_iv_text_decoding_and_bad_set_iv_are_explicit() {
    check(
        r#"(function(){
      var c=java.createSymmetricCrypto('DES','12345678extra','ignored'),ref=java.createSymmetricCrypto('DES/ECB/PKCS5Padding','12345678');
      var a=java.createSymmetricCrypto('AES/ECB/PKCS5Padding','0123456789abcdef','ignored');
      var ct=a.encrypt(new Uint8Array([255]));
      var b=java.createSymmetricCrypto('DESede/ECB/PKCS5Padding','0123456789abcdef01234567extra');
      var shorter=java.createSymmetricCrypto('DESede/ECB/PKCS5Padding','0123456789abcdef01234567');
      var emptyIv=java.createSymmetricCrypto('AES/CBC/PKCS5Padding','0123456789abcdef','');
      var failed=false;emptyIv.setIv(new Uint8Array(0));try{emptyIv.encrypt('hello')}catch(e){failed=true}
      return c.encryptHex('hello')===ref.encryptHex('hello') && b.encryptHex('hello')===shorter.encryptHex('hello') &&
       a.decryptStr(ct)==='\ufffd' && failed &&
       java.aesDecodeToString(a.encryptHex('hello'),'0123456789abcdef','AES/ECB/PKCS5Padding','')==='hello';
    })()"#,
    );
}

#[test]
fn invalid_init_arguments_clear_previous_initialization_and_specs_copy() {
    check(
        r#"(function(){var C=Packages.javax.crypto.Cipher,S=Packages.javax.crypto.spec;
      var key=new S.SecretKeySpec(java.strToBytes('0123456789abcdef'),'AES'),iv=new S.IvParameterSpec(java.strToBytes('fedcba9876543210'));
      key.getEncoded().fill(0);iv.getIV().fill(0);
      var c=C.getInstance('AES/CBC/PKCS5Padding');
      var bad=[()=>c.init(null,key,iv),()=>c.init(1,null,iv),()=>c.init(1,key,{iv:null})];
      return bad.every(function(f){c.init(1,key,iv);var error=false;try{f()}catch(e){error=true}
       try{c.doFinal(java.strToBytes('hello'));return false}catch(e){return error}}) &&
       java.bytesToStr(key.getEncoded())==='0123456789abcdef' && java.bytesToStr(iv.getIV())==='fedcba9876543210';
    })()"#,
    );
}
