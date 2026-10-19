//! 固定上游的两种Base64策略；字体与脚本复用，避免按调用方另写解码规则。
use base64::{
    Engine, alphabet,
    engine::{DecodePaddingMode, GeneralPurpose, GeneralPurposeConfig},
};
fn decoder() -> GeneralPurpose {
    GeneralPurpose::new(
        &alphabet::STANDARD,
        GeneralPurposeConfig::new()
            .with_decode_allow_trailing_bits(true)
            .with_decode_padding_mode(DecodePaddingMode::Indifferent),
    )
}
fn symbol(byte: u8, url_safe: bool) -> bool {
    byte.is_ascii_alphanumeric()
        || if url_safe {
            matches!(byte, b'-' | b'_')
        } else {
            matches!(byte, b'+' | b'/')
        }
}
/// Hutool5.8.22：双字母表、跳过padding/表内非数据、忽略孤立末位。
pub(super) fn decode_hutool(input: &str) -> Result<Vec<u8>, String> {
    let mut data = Vec::with_capacity(input.len());
    for byte in input.bytes() {
        // 固定版本在此范围查表越界；返回错误而非复制越界访问。
        if (123..=127).contains(&byte) {
            return Err("Base64解码字符超出上游查表范围".into());
        }
        let byte = match byte {
            b'-' => b'+',
            b'_' => b'/',
            other => other,
        };
        if symbol(byte, false) {
            data.push(byte);
        }
    }
    if data.len() % 4 == 1 {
        data.pop();
    }
    decoder()
        .decode(data)
        .map_err(|e| format!("Base64解码失败: {e}"))
}
/// Android：仅所选字母表参与解码，padding可省略但出现时必须完整且位于结尾。
#[cfg(any(feature = "quickjs", test))]
pub(super) fn decode_android(input: &str, flags: i32) -> Result<Vec<u8>, String> {
    let url_safe = flags & 8 != 0;
    let mut data: Vec<u8> = input
        .bytes()
        .filter(|&b| b == b'=' || symbol(b, url_safe))
        .collect();
    if let Some(first) = data.iter().position(|&b| b == b'=') {
        let count = data.len() - first;
        if !data.len().is_multiple_of(4)
            || !matches!((first % 4, count), (2, 2) | (3, 1))
            || data[first..].iter().any(|&b| b != b'=')
        {
            return Err("Base64 padding位置或数量不正确".into());
        }
    }
    if url_safe {
        for b in &mut data {
            *b = match *b {
                b'-' => b'+',
                b'_' => b'/',
                other => other,
            };
        }
    }
    decoder()
        .decode(data)
        .map_err(|e| format!("Base64解码失败: {e}"))
}
/// Android编码flags：默认换行且尾部换行；NO_WRAP优先于CRLF。
#[cfg(any(feature = "quickjs", test))]
pub(super) fn encode_android(bytes: &[u8], flags: i32) -> String {
    let alphabet = if flags & 8 != 0 {
        &alphabet::URL_SAFE
    } else {
        &alphabet::STANDARD
    };
    let encoded = GeneralPurpose::new(
        alphabet,
        GeneralPurposeConfig::new().with_encode_padding(flags & 1 == 0),
    )
    .encode(bytes);
    if flags & 2 != 0 {
        return encoded;
    }
    let newline = if flags & 4 != 0 { "\r\n" } else { "\n" };
    let mut output = String::with_capacity(encoded.len() + encoded.len() / 76 * newline.len() + 2);
    for chunk in encoded.as_bytes().chunks(76) {
        // 编码输出恒为ASCII。
        output.push_str(std::str::from_utf8(chunk).expect("Base64输出应为ASCII"));
        output.push_str(newline);
    }
    output
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn hutool_and_android_keep_distinct_padding_and_alphabets() {
        for text in ["Zg", "Zg=", "Zg===", "Z=g=", "Z# g==", "Zh=="] {
            assert_eq!(decode_hutool(text).unwrap(), b"f");
        }
        assert_eq!(decode_hutool("Zg==Zg==").unwrap(), [102, 6, 96]);
        assert!(decode_hutool("a").unwrap().is_empty());
        assert!(decode_hutool("====").unwrap().is_empty());
        assert!(decode_hutool("Z~g==").is_err());
        for text in ["Zg=", "Zg===", "Z=g=", "Zg==Zg==", "a", "===="] {
            assert!(decode_android(text, 0).is_err(), "{text}");
        }
        for text in ["Zg", "Z# g==", "Z~g==", "Zh==", "Zg==中文"] {
            assert_eq!(decode_android(text, 0).unwrap(), b"f");
        }
        assert_eq!(decode_hutool("_w==").unwrap(), [255]);
        assert_eq!(decode_android("_w==", 8).unwrap(), [255]);
        assert!(decode_android("_w==", 0).is_err());
        assert!(decode_android("/w==", 8).is_err());
    }
    #[test]
    fn encoder_wraps_padding_and_empty_output() {
        assert_eq!(encode_android(b"f", 0), "Zg==\n");
        assert_eq!(encode_android(b"f", 5), "Zg\r\n");
        assert_eq!(encode_android(&[255], 11), "_w");
        assert_eq!(encode_android(b"", 0), "");
        assert_eq!(
            encode_android(&[b'x'; 57], 0)
                .lines()
                .map(str::len)
                .collect::<Vec<_>>(),
            [76]
        );
        assert_eq!(
            encode_android(&[b'x'; 58], 0)
                .lines()
                .map(str::len)
                .collect::<Vec<_>>(),
            [76, 4]
        );
    }
}
