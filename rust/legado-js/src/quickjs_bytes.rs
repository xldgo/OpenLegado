//! 字节参数转换与安全复制，避免跨JS调用持有引擎缓冲区借用。

use rquickjs::{FromJs, TypedArray};

pub(crate) fn copy_bytes<T>(array: &TypedArray<'_, T>) -> Option<Vec<u8>> {
    // 安全性：调用方持有 Context 锁；从取得切片到完成复制之间只运行 Rust
    // 内存复制，不调用 JS、不调整或分离缓冲区，也不将借用带出此函数。
    unsafe { array.as_bytes().map(<[u8]>::to_vec) }
}

/// 脚本字节输入在参数转换时即复制，后续字符集ToString可执行JS或分离原缓冲。
pub(crate) struct ByteArray(pub Vec<u8>);

impl<'js> FromJs<'js> for ByteArray {
    fn from_js(ctx: &rquickjs::Ctx<'js>, value: rquickjs::Value<'js>) -> rquickjs::Result<Self> {
        if let Ok(array) = TypedArray::<u8>::from_value(value.clone()) {
            return copy_bytes(&array).map(Self).ok_or_else(|| {
                rquickjs::Error::new_from_js_message("Uint8Array", "bytes", "字节视图已分离或越界")
            });
        }
        if let Ok(array) = TypedArray::<i8>::from_value(value.clone()) {
            return copy_bytes(&array).map(Self).ok_or_else(|| {
                rquickjs::Error::new_from_js_message("Int8Array", "bytes", "字节视图已分离或越界")
            });
        }
        if let Some(array) = value.as_array() {
            let mut bytes = Vec::new();
            for item in array.iter::<rquickjs::Value>() {
                let number = crate::host_api::coerce::RhinoInt::from_js(ctx, item?)?.0;
                let byte = i8::try_from(number).map_err(|_| {
                    rquickjs::Error::new_from_js_message(
                        "number",
                        "byte",
                        "数组元素超出Java byte范围",
                    )
                })?;
                bytes.push(byte as u8);
            }
            return Ok(Self(bytes));
        }
        Err(rquickjs::Error::new_from_js_message(
            value.type_of().as_str(),
            "byte[]",
            "需要8位字节视图或Java byte数组",
        ))
    }
}

/// 非空Java String形参；保留Rhino其余值的ToString转换。
pub(crate) struct TextArg(pub String);
impl<'js> FromJs<'js> for TextArg {
    fn from_js(ctx: &rquickjs::Ctx<'js>, value: rquickjs::Value<'js>) -> rquickjs::Result<Self> {
        if value.is_null() {
            return Err(rquickjs::Error::new_from_js_message(
                "null",
                "String",
                "字符串不能为null",
            ));
        }
        Ok(Self(rquickjs::Coerced::<String>::from_js(ctx, value)?.0))
    }
}

/// 缺省对应单参重载；显式null/undefined不是缺省字符集。
pub(crate) struct CharsetArg(pub Option<String>);
impl<'js> rquickjs::function::FromParam<'js> for CharsetArg {
    fn param_requirement() -> rquickjs::function::ParamRequirement {
        rquickjs::function::ParamRequirement::optional()
    }
    fn from_param<'a>(
        params: &mut rquickjs::function::ParamsAccessor<'a, 'js>,
    ) -> rquickjs::Result<Self> {
        if params.is_empty() {
            return Ok(Self(None));
        }
        let ctx = params.ctx().clone();
        Ok(Self(Some(TextArg::from_js(&ctx, params.arg())?.0)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rquickjs::{Context, Runtime};

    #[test]
    fn copy_respects_view_and_owns_its_bytes() {
        let runtime = Runtime::new().unwrap();
        let context = Context::full(&runtime).unwrap();
        context.with(|ctx| {
            let array: TypedArray<u8> = ctx
                .eval("globalThis.bytes = new Uint8Array([1, 2, 3, 4]); bytes.subarray(1, 3)")
                .unwrap();
            let copied = copy_bytes(&array).unwrap();
            ctx.eval::<(), _>("bytes.fill(9)").unwrap();
            assert_eq!(copied, [2, 3]);
            assert_eq!(copy_bytes(&array).unwrap(), [9, 9]);
        });
    }

    #[test]
    fn empty_resized_and_detached_buffers() {
        let runtime = Runtime::new().unwrap();
        let context = Context::full(&runtime).unwrap();
        context.with(|ctx| {
            let empty: TypedArray<u8> = ctx.eval("new Uint8Array(0)").unwrap();
            assert_eq!(copy_bytes(&empty), Some(Vec::new()));
            let array: TypedArray<u8> = ctx
                .eval("globalThis.buffer = new ArrayBuffer(2, {maxByteLength: 8}); new Uint8Array(buffer, 0, 2)")
                .unwrap();
            assert_eq!(copy_bytes(&array).unwrap().len(), 2);
            ctx.eval::<(), _>("buffer.resize(4)").unwrap();
            // 固定长度视图不随底层缓冲区扩容；缩容越界后不得读取旧范围。
            assert_eq!(copy_bytes(&array).unwrap().len(), 2);
            ctx.eval::<(), _>("buffer.resize(1)").unwrap();
            assert_eq!(copy_bytes(&array), None);
            ctx.eval::<(), _>("buffer.resize(4)").unwrap();
            ctx.eval::<(), _>("buffer.transfer()").unwrap();
            assert_eq!(copy_bytes(&array), None);
        });
    }
}
