//! 摘要脚本边界：名称别名、非null字符串转换与异常统一注册。
//! — Codex + Bridge
use super::{encoding, register::mount_dual};
use crate::quickjs_bytes::TextArg;
use legado_core::LegadoError;
use rquickjs::{Ctx, Function, Object};
type TwoTextFn = fn(&str, &str) -> Result<String, String>;
type ThreeTextFn = fn(&str, &str, &str) -> Result<String, String>;
pub(super) fn register<'js>(
    ctx: &Ctx<'js>,
    java: &Object<'js>,
    globals: &Object<'js>,
) -> Result<(), LegadoError> {
    let map = |error: rquickjs::Error| LegadoError::JsEngine(error.to_string());
    let pairs: [(&str, TwoTextFn); 4] = [
        ("digestHex", encoding::digest_hex),
        ("digestBase64Str", encoding::digest_base64_str),
        ("hmacMd5", encoding::hmac_md5),
        ("hmacSha256", encoding::hmac_sha256),
    ];
    for (name, compute) in pairs {
        mount_dual(
            java,
            globals,
            name,
            Function::new(
                ctx.clone(),
                move |ctx: Ctx<'js>, first: TextArg, second: TextArg| {
                    compute(&first.0, &second.0)
                        .map_err(|error| rquickjs::Exception::throw_message(&ctx, &error))
                },
            )
            .map_err(map)?,
        )?;
    }
    let triples: [(&str, ThreeTextFn); 4] = [
        ("hmacHex", encoding::hmac_hex),
        ("HMacHex", encoding::hmac_hex),
        ("hmacBase64", encoding::hmac_base64),
        ("HMacBase64", encoding::hmac_base64),
    ];
    for (name, compute) in triples {
        mount_dual(
            java,
            globals,
            name,
            Function::new(
                ctx.clone(),
                move |ctx: Ctx<'js>, data: TextArg, algorithm: TextArg, key: TextArg| {
                    compute(&data.0, &algorithm.0, &key.0)
                        .map_err(|error| rquickjs::Exception::throw_message(&ctx, &error))
                },
            )
            .map_err(map)?,
        )?;
    }
    Ok(())
}
