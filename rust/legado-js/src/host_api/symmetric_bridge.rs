//! 对称加密脚本注册：错误直接抛出，原始字节在调用计算前复制。
//! — Codex + Bridge
use super::{coerce::RhinoOptStr, crypto_api, register::mount_dual, symmetric_crypto};
use crate::quickjs_bytes::{ByteArray, TextArg};
use legado_core::LegadoError;
use rquickjs::{Ctx, FromJs, Function, Object, TypedArray, Value, function::Opt};
type TextCipher = fn(&str, &str, Option<&str>) -> Result<String, String>;
type StreamCipher = fn(&str, &str) -> Result<String, String>;
pub(super) fn register<'js>(
    ctx: &Ctx<'js>,
    java: &Object<'js>,
    globals: &Object<'js>,
) -> Result<(), LegadoError> {
    let map = |e: rquickjs::Error| LegadoError::JsEngine(e.to_string());
    let cbc: [(&str, TextCipher); 4] = [
        ("aesEncrypt", crypto_api::aes_encrypt),
        ("aesDecrypt", crypto_api::aes_decrypt),
        ("desEncrypt", crypto_api::des_encrypt),
        ("desDecrypt", crypto_api::des_decrypt),
    ];
    for (name, compute) in cbc {
        mount_dual(
            java,
            globals,
            name,
            Function::new(
                ctx.clone(),
                move |ctx: Ctx<'js>, data: TextArg, key: TextArg, iv: RhinoOptStr| {
                    compute(&data.0, &key.0, iv.0.as_deref())
                        .map_err(|e| rquickjs::Exception::throw_message(&ctx, &e))
                },
            )
            .map_err(map)?,
        )?;
    }
    let stream: [(&str, StreamCipher); 2] = [
        ("rc4Encrypt", crypto_api::rc4_encrypt),
        ("rc4Decrypt", crypto_api::rc4_decrypt),
    ];
    for (name, compute) in stream {
        mount_dual(
            java,
            globals,
            name,
            Function::new(
                ctx.clone(),
                move |ctx: Ctx<'js>, data: TextArg, key: TextArg| {
                    compute(&data.0, &key.0)
                        .map_err(|e| rquickjs::Exception::throw_message(&ctx, &e))
                },
            )
            .map_err(map)?,
        )?;
    }
    mount_dual(
        java,
        globals,
        "createSymmetricCrypto",
        Function::new(
            ctx.clone(),
            |ctx: Ctx<'js>, t: TextArg, key: Value<'js>, iv: Opt<Value<'js>>| {
                symmetric_crypto::create(ctx, &t.0, key, iv)
            },
        )
        .map_err(map)?,
    )?;
    mount_dual(
        java,
        globals,
        "cipherGetInstance",
        Function::new(ctx.clone(), |ctx: Ctx<'js>, t: TextArg| {
            symmetric_crypto::build_cipher(ctx, t.0)
        })
        .map_err(map)?,
    )?;
    java.set(
        "cipherSecretKey",
        Function::new(
            ctx.clone(),
            |ctx: Ctx<'js>, data: ByteArray, algorithm: TextArg| {
                symmetric_crypto::parameter_spec(ctx, data.0, Some(algorithm.0))
            },
        )
        .map_err(map)?
        .with_constructor(true),
    )
    .map_err(map)?;
    java.set(
        "cipherIvParameter",
        Function::new(ctx.clone(), |ctx: Ctx<'js>, data: ByteArray| {
            symmetric_crypto::parameter_spec(ctx, data.0, None)
        })
        .map_err(map)?
        .with_constructor(true),
    )
    .map_err(map)?;
    mount_dual(
        java,
        globals,
        "aesDecryptBytes",
        Function::new(
            ctx.clone(),
            |ctx: Ctx<'js>,
             data: ByteArray,
             key: ByteArray,
             iv: Opt<Value<'js>>,
             t: Opt<Value<'js>>| {
                let iv = match iv.0 {
                    None => None,
                    Some(v) if v.is_null() || v.is_undefined() => None,
                    Some(v) => Some(ByteArray::from_js(&ctx, v)?.0),
                };
                // 字节已复制，之后的字符串转换即便重入JS也不会使借用失效。
                let t = match t.0 {
                    None => "AES/CBC/PKCS5Padding".into(),
                    Some(v) if v.is_null() || v.is_undefined() => "AES/CBC/PKCS5Padding".into(),
                    Some(v) => TextArg::from_js(&ctx, v)?.0,
                };
                let out =
                    legado_core::crypto::symmetric_decrypt(&t, &key.0, iv.as_deref(), &data.0)
                        .map_err(|e| rquickjs::Exception::throw_message(&ctx, &e.to_string()))?;
                TypedArray::new(ctx, out)
            },
        )
        .map_err(map)?,
    )?;
    mount_dual(
        java,
        globals,
        "tripleDESEncodeBase64Str",
        Function::new(
            ctx.clone(),
            |ctx: Ctx<'js>,
             data: TextArg,
             key: TextArg,
             mode: TextArg,
             padding: TextArg,
             iv: TextArg| {
                symmetric_crypto::triple_des_base64(&data.0, &key.0, &mode.0, &padding.0, &iv.0)
                    .map_err(|e| rquickjs::Exception::throw_message(&ctx, &e))
            },
        )
        .map_err(map)?,
    )?;
    for name in ["aesBase64DecodeToString", "aesDecodeToString"] {
        mount_dual(
            java,
            globals,
            name,
            Function::new(
                ctx.clone(),
                |ctx: Ctx<'js>, data: TextArg, key: TextArg, t: TextArg, iv: TextArg| {
                    symmetric_crypto::aes_base64_decode_to_string(&data.0, &key.0, &t.0, &iv.0)
                        .map_err(|e| rquickjs::Exception::throw_message(&ctx, &e))
                },
            )
            .map_err(map)?,
        )?;
    }
    Ok(())
}
