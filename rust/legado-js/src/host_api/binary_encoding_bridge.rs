//! 编码接口重载分派和JS字节边界；与摘要/加密算法分开。
//! — Codex + Bridge
use super::{
    base64_codec,
    coerce::{RhinoInt, RhinoStr},
    encoding,
    register::mount_dual,
};
use crate::quickjs_bytes::{ByteArray, TextArg};
use legado_core::LegadoError;
use rquickjs::{
    Ctx, FromJs, Function, IntoJs, Object, Value,
    function::{FromParam, ParamRequirement, ParamsAccessor, Rest},
};
/// 可空String允许null；undefined仍按Rhino转换为字符串，不当作缺省。
struct NullableText(Option<String>);
impl<'js> FromJs<'js> for NullableText {
    fn from_js(ctx: &Ctx<'js>, value: Value<'js>) -> rquickjs::Result<Self> {
        if value.is_null() {
            Ok(Self(None))
        } else {
            Ok(Self(Some(RhinoStr::from_js(ctx, value)?.0)))
        }
    }
}
/// 仅缺参使用默认，显式null/undefined仍由非空int转换拒绝。
struct Flags(Option<i32>);
impl<'js> FromParam<'js> for Flags {
    fn param_requirement() -> ParamRequirement {
        ParamRequirement::optional()
    }
    fn from_param<'a>(params: &mut ParamsAccessor<'a, 'js>) -> rquickjs::Result<Self> {
        if params.is_empty() {
            return Ok(Self(None));
        }
        let ctx = params.ctx().clone();
        Ok(Self(Some(RhinoInt::from_js(&ctx, params.arg())?.0)))
    }
}
fn error<'js>(ctx: &Ctx<'js>, text: &str) -> rquickjs::Error {
    rquickjs::Exception::throw_message(ctx, text)
}
fn bytes<'js>(ctx: &Ctx<'js>, data: Vec<u8>) -> rquickjs::Result<Value<'js>> {
    rquickjs::TypedArray::new(ctx.clone(), data)?.into_js(ctx)
}
fn decode_text<'js>(
    ctx: Ctx<'js>,
    input: NullableText,
    extra: Rest<Value<'js>>,
) -> rquickjs::Result<String> {
    match extra.0.as_slice() {
        [] => input.0.map_or_else(
            || Ok(String::new()),
            |s| encoding::base64_decode(&s).map_err(|e| error(&ctx, &e)),
        ),
        [value] if value.is_number() => {
            let flags = RhinoInt::from_js(&ctx, value.clone())?.0;
            let input = input
                .0
                .ok_or_else(|| error(&ctx, "flags重载要求非空文本"))?;
            let data = base64_codec::decode_android(&input, flags).map_err(|e| error(&ctx, &e))?;
            encoding::bytes_to_str(&data, None).map_err(|e| error(&ctx, &e))
        }
        [value] => {
            let charset = TextArg::from_js(&ctx, value.clone())?.0;
            let Some(input) = input.0 else {
                return Ok(String::new());
            };
            let data = base64_codec::decode_hutool(&input).map_err(|e| error(&ctx, &e))?;
            encoding::bytes_to_str(&data, Some(&charset)).map_err(|e| error(&ctx, &e))
        }
        _ => Err(error(&ctx, "Base64解码参数数量不匹配")),
    }
}
pub(super) fn register<'js>(
    ctx: &Ctx<'js>,
    java: &Object<'js>,
    globals: &Object<'js>,
) -> Result<(), LegadoError> {
    let map = |e: rquickjs::Error| LegadoError::JsEngine(e.to_string());
    for name in ["base64Decode", "base64Decoder"] {
        mount_dual(
            java,
            globals,
            name,
            Function::new(ctx.clone(), decode_text).map_err(map)?,
        )?;
    }
    mount_dual(
        java,
        globals,
        "base64Encode",
        Function::new(ctx.clone(), |input: TextArg, flags: Flags| {
            base64_codec::encode_android(input.0.as_bytes(), flags.0.unwrap_or(2))
        })
        .map_err(map)?,
    )?;
    mount_dual(
        java,
        globals,
        "base64EncodeBytes",
        Function::new(ctx.clone(), |input: ByteArray, flags: Flags| {
            // ByteArray在flags可能执行JS的ToString前已复制，不能被重入改写。
            base64_codec::encode_android(&input.0, flags.0.unwrap_or(2))
        })
        .map_err(map)?,
    )?;
    mount_dual(
        java,
        globals,
        "base64DecodeToByteArray",
        Function::new(
            ctx.clone(),
            |ctx: Ctx<'js>, input: NullableText, flags: Flags| {
                let Some(input) = input.0.filter(|s| !s.trim().is_empty()) else {
                    return Ok(Value::new_null(ctx));
                };
                bytes(
                    &ctx,
                    base64_codec::decode_android(&input, flags.0.unwrap_or(0))
                        .map_err(|e| error(&ctx, &e))?,
                )
            },
        )
        .map_err(map)?,
    )?;
    mount_dual(
        java,
        globals,
        "hexDecodeToByteArray",
        Function::new(ctx.clone(), |ctx: Ctx<'js>, input: TextArg| {
            bytes(
                &ctx,
                encoding::hex_decode_bytes(&input.0).map_err(|e| error(&ctx, &e))?,
            )
        })
        .map_err(map)?,
    )?;
    for name in ["hexDecode", "hexDecodeToString"] {
        mount_dual(
            java,
            globals,
            name,
            Function::new(ctx.clone(), |ctx: Ctx<'js>, input: TextArg| {
                encoding::hex_decode(&input.0).map_err(|e| error(&ctx, &e))
            })
            .map_err(map)?,
        )?;
    }
    for name in ["hexEncode", "hexEncodeToString"] {
        mount_dual(
            java,
            globals,
            name,
            Function::new(ctx.clone(), |input: TextArg| encoding::hex_encode(&input.0))
                .map_err(map)?,
        )?;
    }
    Ok(())
}
