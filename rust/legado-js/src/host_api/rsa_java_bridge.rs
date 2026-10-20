//! Java RSA适配层：DER参数、KeyFactory与Signature会话复用同一密码学核心。
//! — Codex + Bridge
use super::asymmetric_crypto::{self, KeyArg, SignAlgo, parse_sign_algorithm};
use crate::quickjs_bytes::{ByteArray, TextArg};
use legado_core::LegadoError;
use rquickjs::{
    Ctx, FromJs, Function, Object, TypedArray, Value, function::This, object::Accessor,
};
use rsa::{RsaPrivateKey, RsaPublicKey};
use std::{cell::RefCell, rc::Rc};
fn error(message: impl Into<String>) -> rquickjs::Error {
    rquickjs::Error::new_from_js_message("value", "Java RSA", message.into())
}
fn der_from_spec<'js>(spec: Object<'js>) -> rquickjs::Result<Vec<u8>> {
    let method: Value = if spec.contains_key("getEncoded")? {
        spec.get("getEncoded")?
    } else {
        spec.get("encode")?
    };
    let method = Function::from_js(spec.ctx(), method)
        .map_err(|_| error("KeyFactory参数须为带getEncoded()/encode()方法的spec对象"))?;
    let bytes: ByteArray = method.call((This(spec),))?;
    Ok(bytes.0)
}
/// 构造器只复制；密钥是否合法由KeyFactory生成时判定。
fn key_spec<'js>(ctx: Ctx<'js>, bytes: Vec<u8>, private: bool) -> rquickjs::Result<Object<'js>> {
    let obj = Object::new(ctx.clone())?;
    let bytes = Rc::new(bytes);
    let read = Function::new(ctx.clone(), move |ctx: Ctx<'js>| {
        TypedArray::new(ctx, bytes.as_ref().clone())
    })?;
    obj.set("getEncoded", read.clone())?;
    obj.set("encode", read)?;
    obj.set(
        "getFormat",
        Function::new(ctx, move || if private { "PKCS#8" } else { "X.509" })?,
    )?;
    Ok(obj)
}
fn key_object<'js>(ctx: Ctx<'js>, bytes: Vec<u8>, private: bool) -> rquickjs::Result<Object<'js>> {
    // 生成时校验一次；不以字符串或Base64包裹DER。
    if private {
        use rsa::pkcs8::DecodePrivateKey;
        RsaPrivateKey::from_pkcs8_der(&bytes).map_err(|e| error(e.to_string()))?;
    } else {
        use rsa::pkcs8::DecodePublicKey;
        RsaPublicKey::from_public_key_der(&bytes).map_err(|e| error(e.to_string()))?;
    }
    let obj = key_spec(ctx.clone(), bytes.clone(), private)?;
    let bytes = Rc::new(bytes);
    obj.prop(
        "_key",
        Accessor::from(move |ctx: Ctx<'js>| TypedArray::new(ctx, bytes.as_ref().clone())),
    )?;
    obj.prop("_private", private)?;
    obj.set("getAlgorithm", Function::new(ctx, || "RSA")?)?;
    Ok(obj)
}
fn key_factory<'js>(ctx: Ctx<'js>, algorithm: &str) -> rquickjs::Result<Object<'js>> {
    if !algorithm.eq_ignore_ascii_case("RSA") {
        let java: Object = ctx.globals().get("java")?;
        let report: Function = java.get("reportUnknownSymbol")?;
        report.call::<_, ()>((format!(
            "java.security.KeyFactory.getInstance(\"{algorithm}\")"
        ),))?;
        return Err(error(format!("当前不支持KeyFactory算法: {algorithm}")));
    }
    let obj = Object::new(ctx.clone())?;
    for (name, private) in [("generatePrivate", true), ("generatePublic", false)] {
        obj.set(
            name,
            Function::new(ctx.clone(), move |ctx: Ctx<'js>, spec: Object<'js>| {
                key_object(ctx, der_from_spec(spec)?, private)
            })?,
        )?;
    }
    Ok(obj)
}
enum Mode {
    Sign(Box<RsaPrivateKey>),
    Verify(RsaPublicKey),
}
struct SignatureState {
    mode: Option<Mode>,
    digest: Box<dyn sha2::digest::DynDigest>,
    algo: SignAlgo,
}
fn signature<'js>(ctx: Ctx<'js>, algorithm: &str) -> rquickjs::Result<Object<'js>> {
    let algo = parse_sign_algorithm(algorithm).map_err(error)?;
    let state = Rc::new(RefCell::new(SignatureState {
        mode: None,
        digest: asymmetric_crypto::sign_digest(algo),
        algo,
    }));
    let obj = Object::new(ctx.clone())?;
    for (name, private) in [("initSign", true), ("initVerify", false)] {
        let state = state.clone();
        obj.set(
            name,
            Function::new(
                ctx.clone(),
                move |ctx: Ctx<'js>, this: This<Object<'js>>, key: Value<'js>| {
                    {
                        let mut s = state.borrow_mut();
                        s.mode = None;
                        s.digest.reset();
                    }
                    // 在任何可重入的属性读取之前释放RefCell借用，转换失败保持未初始化。
                    let key = Object::from_js(&ctx, key)?;
                    if key.get::<_, bool>("_private")? != private {
                        return Err(error("Signature密钥类型不匹配"));
                    }
                    let bytes = der_from_spec(key)?;
                    let mode = if private {
                        Mode::Sign(Box::new(KeyArg::Der(bytes).private().map_err(error)?))
                    } else {
                        Mode::Verify(KeyArg::Der(bytes).public().map_err(error)?)
                    };
                    state.borrow_mut().mode = Some(mode);
                    Ok(this.0)
                },
            )?,
        )?;
    }
    let s = state.clone();
    obj.set(
        "update",
        Function::new(
            ctx.clone(),
            move |this: This<Object<'js>>, data: ByteArray| {
                let mut s = s.borrow_mut();
                if s.mode.is_none() {
                    return Err(error("Signature须先调用initSign/initVerify"));
                }
                s.digest.update(&data.0);
                Ok(this.0)
            },
        )?,
    )?;
    let s = state.clone();
    obj.set(
        "sign",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>| {
            let mut s = s.borrow_mut();
            let Some(Mode::Sign(key)) = &s.mode else {
                return Err(error("Signature.sign须先调用initSign"));
            };
            let out =
                asymmetric_crypto::rsa_sign_digest(s.algo, key, &s.digest.box_clone().finalize())
                    .map_err(error)?;
            s.digest.reset();
            TypedArray::new(ctx, out)
        })?,
    )?;
    obj.set(
        "verify",
        Function::new(ctx, move |data: ByteArray| {
            let mut s = state.borrow_mut();
            let Some(Mode::Verify(key)) = &s.mode else {
                return Err(error("Signature.verify须先调用initVerify"));
            };
            let result = asymmetric_crypto::rsa_verify_digest(
                s.algo,
                key,
                &s.digest.box_clone().finalize(),
                &data.0,
            );
            s.digest.reset();
            Ok(result)
        })?,
    )?;
    Ok(obj)
}
/// 内部Packages适配只挂java，既有createSign/createAsymmetricCrypto仍保留双入口。
pub(super) fn register<'js>(ctx: &Ctx<'js>, java: &Object<'js>) -> Result<(), LegadoError> {
    let map = |e: rquickjs::Error| LegadoError::JsEngine(e.to_string());
    for (name, private) in [("rsaPrivateSpec", true), ("rsaPublicSpec", false)] {
        java.set(
            name,
            Function::new(ctx.clone(), move |ctx: Ctx<'js>, bytes: ByteArray| {
                key_spec(ctx, bytes.0, private)
            })
            .map_err(map)?
            .with_constructor(true),
        )
        .map_err(map)?;
    }
    java.set(
        "rsaKeyFactory",
        Function::new(ctx.clone(), |ctx: Ctx<'js>, algorithm: TextArg| {
            key_factory(ctx, &algorithm.0)
        })
        .map_err(map)?,
    )
    .map_err(map)?;
    java.set(
        "rsaSignature",
        Function::new(ctx.clone(), |ctx: Ctx<'js>, algorithm: TextArg| {
            signature(ctx, &algorithm.0)
        })
        .map_err(map)?,
    )
    .map_err(map)?;
    Ok(())
}
