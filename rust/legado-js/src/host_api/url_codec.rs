//! 表单URL编解码；不替代JavaScript引擎的URI内建函数。
use super::encoding;
fn safe(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.' | b'*')
}
/// Java字符集名称不接受Web编码标签的首尾空白等宽松别名。
fn validate_charset(charset: &str) -> Result<(), String> {
    let bytes = charset.as_bytes();
    if bytes.first().is_none_or(|b| !b.is_ascii_alphanumeric())
        || bytes
            .iter()
            .any(|b| !b.is_ascii_alphanumeric() && !matches!(b, b'-' | b'_' | b'.' | b':' | b'+'))
    {
        return Err("非法字符集名称".into());
    }
    encoding::str_to_bytes("", Some(charset)).map(|_| ())
}
/// 非安全连续段独立编码；UTF-16的BOM不能跨ASCII安全字符合并。
pub(super) fn encode_form(input: &str, charset: &str) -> Result<String, String> {
    validate_charset(charset)?;
    const HEX: &[u8] = b"0123456789ABCDEF";
    let mut output = String::with_capacity(input.len());
    let mut start = 0;
    for (index, ch) in input.char_indices() {
        if ch == ' ' || ch.is_ascii() && safe(ch as u8) {
            if start < index {
                percent_bytes(
                    &encoding::str_to_bytes(&input[start..index], Some(charset))?,
                    &mut output,
                    HEX,
                );
            }
            output.push(if ch == ' ' { '+' } else { ch });
            start = index + ch.len_utf8();
        }
    }
    if start < input.len() {
        percent_bytes(
            &encoding::str_to_bytes(&input[start..], Some(charset))?,
            &mut output,
            HEX,
        );
    }
    Ok(output)
}
fn percent_bytes(bytes: &[u8], output: &mut String, hex: &[u8]) {
    for &byte in bytes {
        output.push('%');
        output.push(hex[(byte >> 4) as usize] as char);
        output.push(hex[(byte & 15) as usize] as char);
    }
}
/// UTF-8表单解码：仅连续%HH字节做转码，普通文本保留，+单独还原空格。
pub(super) fn decode_form(input: &str) -> Result<String, String> {
    let mut output = String::with_capacity(input.len());
    let mut index = 0;
    let input_bytes = input.as_bytes();
    while index < input.len() {
        match input_bytes[index] {
            b'+' => {
                output.push(' ');
                index += 1;
            }
            b'%' => {
                let mut bytes = Vec::new();
                while input_bytes.get(index) == Some(&b'%') {
                    let pair = input_bytes
                        .get(index + 1..index + 3)
                        .ok_or_else(|| "不完整的URL百分号转义".to_string())?;
                    let high = (pair[0] as char).to_digit(16);
                    let low = (pair[1] as char).to_digit(16);
                    let (Some(high), Some(low)) = (high, low) else {
                        return Err("无效的URL百分号转义".into());
                    };
                    bytes.push(((high << 4) | low) as u8);
                    index += 3;
                }
                output.push_str(&encoding::bytes_to_str(&bytes, None)?);
            }
            _ => {
                let ch = input[index..]
                    .chars()
                    .next()
                    .expect("索引保持UTF-8字符边界");
                output.push(ch);
                index += ch.len_utf8();
            }
        }
    }
    Ok(output)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn form_charset_vectors_and_invalid_names_are_not_web_label_fallbacks() {
        for (charset, expected) in [
            ("UTF-8", "%C3%A9"),
            ("GBK", "%A8%A6"),
            ("UTF-16BE", "%00%E9"),
            ("US-ASCII", "%3F"),
            ("ISO-8859-1", "%E9"),
        ] {
            assert_eq!(encode_form("é", charset).unwrap(), expected);
        }
        for name in ["", "bad", "utf-8 ", " utf-8", "utf\n8"] {
            assert!(encode_form("abc", name).is_err(), "{name}");
        }
        assert_eq!(decode_form("原文+%E4%B8%AD%2B").unwrap(), "原文 中+");
    }
}
