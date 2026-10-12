//! 将 QuickJS 缓冲区复制为 Rust 自有字节，避免跨 JS 调用持有引擎内存的借用。

use rquickjs::TypedArray;

pub(crate) fn copy_bytes(array: &TypedArray<'_, u8>) -> Option<Vec<u8>> {
    // 安全性：调用方持有 Context 锁；从取得切片到完成复制之间只运行 Rust
    // 内存复制，不调用 JS、不调整或分离缓冲区，也不将借用带出此函数。
    unsafe { array.as_bytes().map(<[u8]>::to_vec) }
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
