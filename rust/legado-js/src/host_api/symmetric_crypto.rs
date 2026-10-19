//! 对称加密对象与原生Cipher共用字节计算；脚本对象不参与Rust状态的引用计数。
//! — Codex + Bridge
use super::{coerce::RhinoInt, encoding};
use crate::quickjs_bytes::{ByteArray, TextArg};
use base64::{Engine as _, engine::general_purpose::STANDARD as B64};
use legado_core::crypto::{self, parse_transformation};
use rquickjs::{
    Ctx, FromJs, Function, Object, Result as JsResult, TypedArray, Value,
    function::{Opt, This},
};
use std::{cell::RefCell, rc::Rc};

fn js_err(msg: impl Into<String>) -> rquickjs::Error {
    rquickjs::Error::new_from_js_message("value", "SymmetricCrypto", msg.into())
}
fn random_bytes(length: usize) -> Result<Vec<u8>, String> {
    use rand_core::RngCore;
    let mut bytes = vec![0; length];
    rand_core::OsRng
        .try_fill_bytes(&mut bytes)
        .map_err(|e| format!("安全随机数失败: {e}"))?;
    Ok(bytes)
}
fn key_size(transformation: &str) -> Result<usize, String> {
    let (algo, _, _) = parse_transformation(transformation)?;
    match algo.as_str() {
        "AES" | "RC4" => Ok(16),
        "DES" => Ok(8),
        "DESEDE" => Ok(24),
        _ => Err(format!("Unsupported algorithm: {algo}")),
    }
}

/// 仅对象式上游适配执行密钥截断，原生Cipher仍校验原始长度。
fn normalize_key(transformation: &str, mut key: Vec<u8>) -> Result<Vec<u8>, String> {
    match parse_transformation(transformation)?.0.as_str() {
        "DES" if key.len() > 8 => key.truncate(8),
        "DESEDE" if key.len() > 24 => key.truncate(24),
        _ => {}
    }
    Ok(key)
}
fn value_to_bytes<'js>(ctx: &Ctx<'js>, value: Value<'js>) -> JsResult<Vec<u8>> {
    if value.is_string() {
        return Ok(String::from_js(ctx, value)?.into_bytes());
    }
    Ok(ByteArray::from_js(ctx, value)?.0)
}
fn cipher_bytes<'js>(ctx: &Ctx<'js>, value: Value<'js>) -> JsResult<Vec<u8>> {
    if value.is_string() {
        let text = String::from_js(ctx, value)?;
        if text.len().is_multiple_of(2) && text.bytes().all(|b| b.is_ascii_hexdigit()) {
            return hex::decode(text).map_err(|e| js_err(e.to_string()));
        }
        return super::base64_codec::decode_hutool(&text).map_err(js_err);
    }
    Ok(ByteArray::from_js(ctx, value)?.0)
}
fn plain_bytes<'js>(
    ctx: &Ctx<'js>,
    value: Value<'js>,
    charset: Opt<Value<'js>>,
) -> JsResult<Vec<u8>> {
    if value.is_string() {
        let text = String::from_js(ctx, value)?;
        let charset = match charset.0 {
            None => None,
            Some(v) if v.is_null() => None,
            Some(v) => Some(TextArg::from_js(ctx, v)?.0),
        };
        return encoding::str_to_bytes(&text, charset.as_deref()).map_err(js_err);
    }
    Ok(ByteArray::from_js(ctx, value)?.0)
}

/// 参数对象直接使用原生回调，避免启动时额外编译成组JS方法。
pub(super) fn parameter_spec<'js>(
    ctx: Ctx<'js>,
    bytes: Vec<u8>,
    algorithm: Option<String>,
) -> JsResult<Object<'js>> {
    use rquickjs::object::Accessor;
    if let Some(name) = &algorithm
        && (name.is_empty() || bytes.is_empty())
    {
        return Err(js_err("密钥或算法不能为空"));
    }
    let key = algorithm.is_some();
    let bytes = Rc::new(bytes);
    let obj = Object::new(ctx.clone())?;
    let copy = bytes.clone();
    obj.prop(
        if key { "key" } else { "iv" },
        Accessor::from(move |ctx: Ctx<'js>| TypedArray::new(ctx, copy.as_ref().clone())),
    )?;
    obj.set(
        if key { "getEncoded" } else { "getIV" },
        Function::new(ctx.clone(), move |ctx: Ctx<'js>| {
            TypedArray::new(ctx, bytes.as_ref().clone())
        })?,
    )?;
    if let Some(name) = algorithm {
        obj.prop("algo", name.clone())?;
        obj.set("getAlgorithm", Function::new(ctx, move || name.clone())?)?;
    }
    Ok(obj)
}

struct SymState {
    transformation: String,
    key: Vec<u8>,
    iv: Option<Vec<u8>>,
}
impl SymState {
    fn decrypt(&self, data: &[u8]) -> Result<Vec<u8>, String> {
        crypto::symmetric_decrypt(&self.transformation, &self.key, self.iv.as_deref(), data)
            .map_err(|e| e.to_string())
    }
    fn encrypt(&self, data: &[u8]) -> Result<Vec<u8>, String> {
        let (_, mode, _) = parse_transformation(&self.transformation)?;
        let generated = if mode == "CBC" && self.iv.is_none() {
            Some(random_bytes(if key_size(&self.transformation)? == 16 {
                16
            } else {
                8
            })?)
        } else {
            None
        };
        crypto::symmetric_encrypt(
            &self.transformation,
            &self.key,
            self.iv.as_deref().or(generated.as_deref()),
            data,
        )
        .map_err(|e| e.to_string())
    }
}

/// 工厂的String/ByteArray重载统一到自有字节；null密钥按参考版安全随机生成。
pub(super) fn create<'js>(
    ctx: Ctx<'js>,
    transformation: &str,
    key: Value<'js>,
    iv: Opt<Value<'js>>,
) -> JsResult<Object<'js>> {
    let size = key_size(transformation).map_err(js_err)?;
    let key = if key.is_null() {
        random_bytes(size).map_err(js_err)?
    } else {
        value_to_bytes(&ctx, key)?
    };
    let key = normalize_key(transformation, key).map_err(js_err)?;
    let (_, mode, _) = parse_transformation(transformation).map_err(js_err)?;
    let iv = match iv.0 {
        None => None,
        Some(v) if v.is_null() || v.is_undefined() => None,
        Some(v) => Some(value_to_bytes(&ctx, v)?),
    };
    let iv = iv.filter(|v| !v.is_empty() && mode != "ECB");
    crypto::validate_symmetric_parameters(transformation, &key, iv.as_deref())
        .map_err(|e| js_err(e.to_string()))?;
    build_symmetric_crypto_object(ctx, transformation, &key, iv.as_deref())
}

pub fn build_symmetric_crypto_object<'js>(
    ctx: Ctx<'js>,
    transformation: &str,
    key: &[u8],
    iv: Option<&[u8]>,
) -> JsResult<Object<'js>> {
    crypto::validate_symmetric_parameters(transformation, key, iv)
        .map_err(|e| js_err(e.to_string()))?;
    let state = Rc::new(RefCell::new(SymState {
        transformation: transformation.into(),
        key: key.to_vec(),
        iv: iv.map(<[u8]>::to_vec),
    }));
    let obj = Object::new(ctx.clone())?;
    let st = state.clone();
    obj.set(
        "decrypt",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>, data: Value<'js>| {
            let bytes = cipher_bytes(&ctx, data)?;
            TypedArray::new(ctx, st.borrow().decrypt(&bytes).map_err(js_err)?)
        })?,
    )?;
    let st = state.clone();
    obj.set(
        "decryptStr",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>, data: Value<'js>| {
            let bytes = cipher_bytes(&ctx, data)?;
            encoding::bytes_to_str(&st.borrow().decrypt(&bytes).map_err(js_err)?, None)
                .map_err(js_err)
        })?,
    )?;
    let st = state.clone();
    obj.set(
        "encrypt",
        Function::new(
            ctx.clone(),
            move |ctx: Ctx<'js>, data: Value<'js>, charset: Opt<Value<'js>>| {
                let bytes = plain_bytes(&ctx, data, charset)?;
                TypedArray::new(ctx, st.borrow().encrypt(&bytes).map_err(js_err)?)
            },
        )?,
    )?;
    let st = state.clone();
    obj.set(
        "encryptBase64",
        Function::new(
            ctx.clone(),
            move |ctx: Ctx<'js>, data: Value<'js>, charset: Opt<Value<'js>>| -> JsResult<String> {
                let bytes = plain_bytes(&ctx, data, charset)?;
                Ok(B64.encode(st.borrow().encrypt(&bytes).map_err(js_err)?))
            },
        )?,
    )?;
    let st = state.clone();
    obj.set(
        "encryptHex",
        Function::new(
            ctx.clone(),
            move |ctx: Ctx<'js>, data: Value<'js>| -> JsResult<String> {
                let bytes = plain_bytes(&ctx, data, Opt(None))?;
                Ok(hex::encode(st.borrow().encrypt(&bytes).map_err(js_err)?))
            },
        )?,
    )?;
    // 从调用参数获取this而不捕获obj，避免Rust闭包与JS对象构成不可回收引用环。
    obj.set(
        "setIv",
        Function::new(ctx, move |this: This<Object<'js>>, iv: ByteArray| {
            state.borrow_mut().iv = Some(iv.0);
            this.0
        })?,
    )?;
    Ok(obj)
}

/// 原生Cipher持有独立初始化快照；与工厂共用计算，不继承工厂的密钥截断规则。
pub(super) fn build_cipher<'js>(ctx: Ctx<'js>, transformation: String) -> JsResult<Object<'js>> {
    let size = key_size(&transformation).map_err(js_err)?;
    crypto::validate_symmetric_parameters(&transformation, &vec![0; size], None)
        .map_err(|e| js_err(e.to_string()))?;
    let state: Rc<RefCell<Option<(bool, SymState)>>> = Rc::new(RefCell::new(None));
    let obj = Object::new(ctx.clone())?;
    let st = state.clone();
    let t = transformation.clone();
    obj.set(
        "init",
        Function::new(
            ctx.clone(),
            move |ctx: Ctx<'js>,
                  mode: Value<'js>,
                  key: Value<'js>,
                  iv: Opt<Value<'js>>|
                  -> JsResult<()> {
                *st.borrow_mut() = None;
                let mode = RhinoInt::from_js(&ctx, mode)?;
                let key = Object::from_js(&ctx, key)?;
                if !matches!(mode.0, 1 | 2) {
                    return Err(js_err("不支持的Cipher操作模式"));
                }
                let expected = parse_transformation(&t).map_err(js_err)?.0;
                let algo = key.get::<_, TextArg>("algo")?.0;
                if !algo.eq_ignore_ascii_case(&expected) {
                    return Err(js_err("密钥算法与Cipher不匹配"));
                }
                let key = key.get::<_, ByteArray>("key")?.0;
                let mut iv = match iv.0 {
                    None => None,
                    Some(v) if v.is_null() => None,
                    Some(v) => Some(Object::from_js(&ctx, v)?.get::<_, ByteArray>("iv")?.0),
                };
                let (_, m, _) = parse_transformation(&t).map_err(js_err)?;
                if m == "ECB" && iv.is_some() {
                    return Err(js_err("ECB不接受IV"));
                }
                if m == "CBC" && iv.is_none() {
                    if mode.0 == 2 {
                        return Err(js_err("CBC解密需要IV"));
                    }
                    iv =
                        Some(random_bytes(if expected == "AES" { 16 } else { 8 }).map_err(js_err)?);
                }
                crypto::validate_symmetric_parameters(&t, &key, iv.as_deref())
                    .map_err(|e| js_err(e.to_string()))?;
                *st.borrow_mut() = Some((
                    mode.0 == 1,
                    SymState {
                        transformation: t.clone(),
                        key,
                        iv,
                    },
                ));
                Ok(())
            },
        )?,
    )?;
    let st = state.clone();
    obj.set(
        "doFinal",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>, data: Opt<ByteArray>| {
            let data = data.0.map(|v| v.0).unwrap_or_default();
            let borrow = st.borrow();
            let (encrypt, s) = borrow.as_ref().ok_or_else(|| js_err("Cipher尚未初始化"))?;
            let out = if *encrypt {
                s.encrypt(&data)
            } else {
                s.decrypt(&data)
            }
            .map_err(js_err)?;
            TypedArray::new(ctx, out)
        })?,
    )?;
    obj.set(
        "getIV",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>| -> JsResult<Value<'js>> {
            use rquickjs::IntoJs;
            let st = state.borrow();
            match st.as_ref().and_then(|(_, s)| s.iv.as_ref()) {
                Some(iv) => TypedArray::new(ctx.clone(), iv.clone())?.into_js(&ctx),
                None => Ok(Value::new_null(ctx)),
            }
        })?,
    )?;
    obj.set(
        "getAlgorithm",
        Function::new(ctx, move || transformation.clone())?,
    )?;
    Ok(obj)
}

/// 两个既有AES字符串别名都按参考版走自动Hex/Base64识别。
pub fn aes_base64_decode_to_string(
    data: &str,
    key: &str,
    transformation: &str,
    iv: &str,
) -> Result<String, String> {
    let bytes = if data.len().is_multiple_of(2) && data.bytes().all(|b| b.is_ascii_hexdigit()) {
        hex::decode(data).map_err(|e| e.to_string())?
    } else {
        super::base64_codec::decode_hutool(data)?
    };
    let (_, mode, _) = parse_transformation(transformation)?;
    let iv = if iv.is_empty() || mode == "ECB" {
        None
    } else {
        Some(iv.as_bytes())
    };
    let key = normalize_key(transformation, key.as_bytes().to_vec())?;
    encoding::bytes_to_str(
        &crypto::symmetric_decrypt(transformation, &key, iv, &bytes).map_err(|e| e.to_string())?,
        None,
    )
}

/// 旧3DES脚本入口仍委托同一对象策略，不另维护密钥或IV规则。
pub(super) fn triple_des_base64(
    data: &str,
    key: &str,
    mode: &str,
    padding: &str,
    iv: &str,
) -> Result<String, String> {
    let transformation = format!("DESede/{mode}/{padding}");
    let key = normalize_key(&transformation, key.as_bytes().to_vec())?;
    let (_, mode, _) = parse_transformation(&transformation)?;
    let iv = if iv.is_empty() || mode == "ECB" {
        None
    } else {
        Some(iv.as_bytes().to_vec())
    };
    let state = SymState {
        transformation,
        key,
        iv,
    };
    Ok(B64.encode(state.encrypt(data.as_bytes())?))
}

#[cfg(test)]
mod tests {
    use super::*;
    use legado_core::crypto::AesCrypto;

    #[test]
    fn test_aes_base64_decode_to_string_pkcs() {
        let key = "0123456789abcdef";
        let iv = "fedcba9876543210";
        let plain = "kaimanhua-aes-payload";
        let ct = AesCrypto::encrypt_cbc(key.as_bytes(), iv.as_bytes(), plain.as_bytes()).unwrap();
        let b64 = B64.encode(&ct);
        let out = aes_base64_decode_to_string(&b64, key, "AES/CBC/PKCS5Padding", iv).unwrap();
        assert_eq!(out, plain);
    }

    #[test]
    fn test_sym_state_nopadding_bytes() {
        let key = b"0123456789abcdef";
        let iv = b"fedcba9876543210";
        let plain = b"0123456789abcdef0123456789abcdef";
        let ct = AesCrypto::encrypt_cbc_nopadding(key, iv, plain).unwrap();
        let st = SymState {
            transformation: "AES/CBC/NoPadding".into(),
            key: key.to_vec(),
            iv: Some(iv.to_vec()),
        };
        let pt = st.decrypt(&ct).unwrap();
        assert_eq!(&pt, plain);
    }

    // #135 阅文 QDSign：createSymmetricCrypto("DESede/CBC/PKCS5Padding", key0, iv)
    // 16 字节密钥（base64(md5)）→ 双密钥 EDE；此处用 NoPadding 变体验证 SymState
    // 经 symmetric_decrypt 的 DESEDE 分发
    #[test]
    fn test_sym_state_desede_bytes() {
        use legado_core::crypto::TripleDesCrypto;

        let key = b"0123456789abcdef"; // 16 bytes
        let iv = b"00000000";
        let plain = b"DESedeNoPadding1"; // 16 bytes（8 的倍数）
        let ct = TripleDesCrypto::encrypt_cbc_nopadding(key, iv, plain).unwrap();
        let st = SymState {
            transformation: "DESede/CBC/NoPadding".into(),
            key: key.to_vec(),
            iv: Some(iv.to_vec()),
        };
        let pt = st.decrypt(&ct).unwrap();
        assert_eq!(&pt, plain);
    }
}
