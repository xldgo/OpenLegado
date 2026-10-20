//! 归档实际输出预算；声明长度只用于预检，不用于整条目预分配。
use legado_core::{LegadoError, LegadoResult};
use std::io::{Read, Write};

pub(crate) const MAX_ENTRIES: usize = 100_000;
pub(crate) const MAX_PAGE_BYTES: u64 = 128 * 1024 * 1024;
pub(crate) fn exceeded() -> LegadoError {
    LegadoError::BookParse("归档内容超出资源预算".into())
}
fn consume(
    reader: &mut impl Read,
    limit: u64,
    mut accept: impl FnMut(&[u8]) -> LegadoResult<()>,
) -> LegadoResult<u64> {
    let mut total = 0u64;
    let mut buffer = [0; 16 * 1024];
    loop {
        let n = match reader.read(&mut buffer) {
            Err(error) if error.kind() == std::io::ErrorKind::Interrupted => continue,
            result => result?,
        };
        if n == 0 {
            return Ok(total);
        }
        total = total.checked_add(n as u64).ok_or_else(exceeded)?;
        if total > limit {
            return Err(exceeded());
        }
        accept(&buffer[..n])?;
    }
}
pub(crate) fn read_bounded(reader: &mut impl Read, limit: u64) -> LegadoResult<Vec<u8>> {
    let mut output = Vec::new();
    consume(reader, limit, |bytes| {
        output
            .try_reserve(bytes.len())
            .map_err(|e| LegadoError::BookParse(format!("分配归档缓冲失败: {e}")))?;
        output.extend_from_slice(bytes);
        Ok(())
    })?;
    Ok(output)
}
pub(crate) fn copy_bounded(
    reader: &mut impl Read,
    writer: &mut impl Write,
    limit: u64,
) -> LegadoResult<u64> {
    consume(reader, limit, |bytes| {
        writer.write_all(bytes)?;
        Ok(())
    })
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn interrupted_read_retries_without_losing_data_or_budget() {
        struct InterruptedOnce<'a>(bool, &'a [u8]);
        impl Read for InterruptedOnce<'_> {
            fn read(&mut self, buffer: &mut [u8]) -> std::io::Result<usize> {
                if !self.0 {
                    self.0 = true;
                    return Err(std::io::ErrorKind::Interrupted.into());
                }
                self.1.read(buffer)
            }
        }
        assert_eq!(
            read_bounded(&mut InterruptedOnce(false, b"1234"), 4).unwrap(),
            b"1234"
        );
        assert!(read_bounded(&mut InterruptedOnce(false, b"12345"), 4).is_err());
    }
    #[test]
    fn actual_output_is_bounded_without_trusting_metadata() {
        assert!(read_bounded(&mut &b"12345"[..], 4).is_err());
        assert_eq!(read_bounded(&mut &b"1234"[..], 4).unwrap(), b"1234");
        let mut out = Vec::new();
        assert!(copy_bounded(&mut &b"12345"[..], &mut out, 4).is_err());
        assert!(out.is_empty());
    }
}
