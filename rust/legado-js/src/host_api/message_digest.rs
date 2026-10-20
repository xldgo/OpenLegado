//! `java.security.MessageDigest` 纯 Rust 摘要核心（Java 能力体系）
//!
//! 既有语料中的 `java.security.MessageDigest` 调用包括：
//! - 🏷七猫小说·API：`Packages...getInstance('MD5').digest(bytes)` 一次性；
//! - 🏷微信读书二合一本地源：`Packages...getInstance("SHA-256").digest(bytes)`
//!   一次性（输入为带符号字节的 plain Array，shim 侧 `toU8` 归一）；
//! - 📂酷狗小说：`java...getInstance("MD5")` + `update(bytes)` + `digest()` 增量。
//!
//! 算法解析 + 摘要计算为纯 Rust（复用 workspace 既有 `md-5`/`sha1`/`sha2` 依赖，
//! 无新增依赖）。输出为**字节数组**（Java `MessageDigest.digest(byte[])` 语义，
//! 非 hex/base64 字符串）；字符串入口在同一计算结果上选择输出编码。
//! 未知算法由调用方（`quickjs_impl` 的 shim）登记能力台账并抛可读文案，
//! 本核心提供能力判定、摘要与HMAC字节计算，不持有脚本对象。
//!
//! 支持MD5及SHA-1/224/256/384/512；同时供字符串摘要和HMAC复用字节计算。

use md5::Md5;
use sha1::Sha1;
use sha2::{Digest, Sha224, Sha256, Sha384, Sha512};

/// 字符串摘要与Packages能力目录共用算法集合。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DigestAlgo {
    Md5,
    Sha1,
    Sha224,
    Sha256,
    Sha384,
    Sha512,
}

/// 规范化算法名：去非字母数字 + 转大写。
///
/// 保留Packages已有的宽松名称兼容，剥离分隔符后归一。
/// 其中 `SHA 256` 等空白写法属于项目扩展，不宣称JDK Provider支持。
fn normalize(name: &str) -> String {
    name.chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .map(|c| c.to_ascii_uppercase())
        .collect()
}

/// 解析算法名 → 支持的算法；未知返回 `None`。
pub fn parse_algorithm(name: &str) -> Option<DigestAlgo> {
    parse_compact(&normalize(name))
}

/// 调用方先按各自已确认的别名策略归一，计算层只消费规范算法标识。
pub(super) fn parse_compact(name: &str) -> Option<DigestAlgo> {
    match name {
        "MD5" => Some(DigestAlgo::Md5),
        "SHA" | "SHA1" => Some(DigestAlgo::Sha1),
        "SHA224" => Some(DigestAlgo::Sha224),
        "SHA256" => Some(DigestAlgo::Sha256),
        "SHA384" => Some(DigestAlgo::Sha384),
        "SHA512" => Some(DigestAlgo::Sha512),
        _ => None,
    }
}

/// 判定算法是否受支持（供 JS 侧 `getInstance` 前置校验；未知算法据此走
/// 「登记台账 + 抛可读文案」路径，不得静默）。
pub fn is_supported_algorithm(name: &str) -> bool {
    parse_algorithm(name).is_some()
}

/// 计算摘要：字节数组输入 → 字节数组输出（Java `MessageDigest.digest(byte[])`
/// 语义，返回值即摘要字节而非十六进制串）。未知算法返回 `Err`。
pub fn digest_bytes(algorithm: &str, data: &[u8]) -> Result<Vec<u8>, String> {
    let algorithm = parse_algorithm(algorithm)
        .ok_or_else(|| format!("unsupported MessageDigest algorithm: {algorithm}"))?;
    Ok(hash_bytes(algorithm, data))
}

/// 唯一一次性摘要计算入口；输出表示由调用方选择。
pub(super) fn hash_bytes(algorithm: DigestAlgo, data: &[u8]) -> Vec<u8> {
    match algorithm {
        DigestAlgo::Md5 => Md5::digest(data).to_vec(),
        DigestAlgo::Sha1 => Sha1::digest(data).to_vec(),
        DigestAlgo::Sha224 => Sha224::digest(data).to_vec(),
        DigestAlgo::Sha256 => Sha256::digest(data).to_vec(),
        DigestAlgo::Sha384 => Sha384::digest(data).to_vec(),
        DigestAlgo::Sha512 => Sha512::digest(data).to_vec(),
    }
}

/// HMAC继续复用原有RustCrypto Hmac实现；Hex/Base64不再各维护一套计算分支。
pub(super) fn hmac_bytes(
    algorithm: DigestAlgo,
    key: &[u8],
    data: &[u8],
) -> Result<Vec<u8>, String> {
    use hmac::{Hmac, Mac};
    if key.is_empty() {
        return Err("HMAC密钥不能为空".into());
    }
    macro_rules! compute {
        ($hash:ty) => {{
            let mut mac = Hmac::<$hash>::new_from_slice(key)
                .map_err(|error| format!("HMAC密钥错误: {error}"))?;
            mac.update(data);
            Ok(mac.finalize().into_bytes().to_vec())
        }};
    }
    match algorithm {
        DigestAlgo::Md5 => compute!(Md5),
        DigestAlgo::Sha1 => compute!(Sha1),
        DigestAlgo::Sha224 => compute!(Sha224),
        DigestAlgo::Sha256 => compute!(Sha256),
        DigestAlgo::Sha384 => compute!(Sha384),
        DigestAlgo::Sha512 => compute!(Sha512),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn supported_inputs() -> Vec<&'static str> {
        // 覆盖大小写 / 连字符 / 空白等写法（归一化口径回归）
        vec![
            "MD5",
            "md5",
            "Md5",
            "SHA-1",
            "sha1",
            "SHA",
            "SHA-224",
            "sha224",
            "SHA-384",
            "sha384",
            "SHA-256",
            "sha256",
            "SHA256",
            "SHA - 512",
            "sha512",
            "SHA512",
        ]
    }

    #[test]
    fn test_parse_algorithm_supported() {
        for input in supported_inputs() {
            assert!(
                parse_algorithm(input).is_some(),
                "受支持算法应解析成功: {input}"
            );
            assert!(
                is_supported_algorithm(input),
                "受支持算法应判定为 true: {input}"
            );
        }
    }

    #[test]
    fn test_parse_algorithm_rejects_unknown() {
        // 已声明集合以外的算法明确拒绝，不静默回退。
        for unknown in ["SHA-512/224", "SHA3-256", "BOGUS", "", "MD5WITHRSA"] {
            assert!(
                parse_algorithm(unknown).is_none(),
                "未知算法应解析为 None: {unknown}"
            );
            assert!(
                !is_supported_algorithm(unknown),
                "未知算法应判定为 false: {unknown}"
            );
        }
    }

    /// RFC 1321（MD5）+ RFC 6234（SHA-1/256/512）标准向量：每种算法 ≥2 条。
    /// 期望值经 Python `hashlib` 独立重算交叉验证（2026-09-25）。
    #[test]
    fn test_digest_bytes_standard_vectors() {
        let vectors: Vec<(&str, &[u8], &str)> = vec![
            // MD5（RFC 1321 空值 / abc / message digest）
            ("MD5", b"", "d41d8cd98f00b204e9800998ecf8427e"),
            ("MD5", b"abc", "900150983cd24fb0d6963f7d28e17f72"),
            ("MD5", b"message digest", "f96b697d7cb7938d525a2f31aaf161d0"),
            // SHA-1（RFC 3174 示例 + 空值）
            ("SHA-1", b"", "da39a3ee5e6b4b0d3255bfef95601890afd80709"),
            ("SHA-1", b"abc", "a9993e364706816aba3e25717850c26c9cd0d89d"),
            (
                "SHA-1",
                b"message digest",
                "c12252ceda8be8994d5fa0290a47231c1d16aae3",
            ),
            // SHA-256（RFC 6234 + 空值）
            (
                "SHA-256",
                b"",
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            ),
            (
                "SHA-256",
                b"abc",
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            ),
            (
                "SHA-256",
                b"message digest",
                "f7846f55cf23e14eebeab5b4e1550cad5b509e3348fbc4efa3a1413d393cb650",
            ),
            // SHA-512（RFC 6234 空值 + abc）
            (
                "SHA-512",
                b"",
                "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce\
                 47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e",
            ),
            (
                "SHA-512",
                b"abc",
                "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a\
                 2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
            ),
        ];

        for (algo, data, expected_hex) in &vectors {
            let out = digest_bytes(algo, data)
                .unwrap_or_else(|e| panic!("受支持算法摘要计算失败 {algo}: {e}"));
            let got_hex = hex::encode(out);
            assert_eq!(
                got_hex,
                *expected_hex,
                "{algo}({:?}) 摘要应与标准向量一致；观测: {got_hex}",
                String::from_utf8_lossy(data)
            );
        }
    }

    /// 摘要长度与算法匹配（Java `MessageDigest.getDigestLength` 语义）
    #[test]
    fn test_digest_length_matches_algorithm() {
        let cases: Vec<(&str, usize)> = vec![
            ("MD5", 16),
            ("SHA-1", 20),
            ("SHA-224", 28),
            ("SHA-256", 32),
            ("SHA-384", 48),
            ("SHA-512", 64),
        ];
        for (algo, len) in cases {
            let out = digest_bytes(algo, b"abc").expect("摘要计算失败");
            assert_eq!(
                out.len(),
                len,
                "{algo} 摘要长度应为 {len} 字节；观测: {}",
                out.len()
            );
        }
    }

    /// 未知算法：`digest_bytes` 返回 `Err`（不静默、不产出空摘要）
    #[test]
    fn test_digest_bytes_unknown_algorithm_errors() {
        for unknown in ["SHA3-384", "BOGUS", ""] {
            let err = digest_bytes(unknown, b"abc").expect_err("未知算法应返回 Err");
            assert!(err.contains(unknown), "错误信息应点名未知算法；观测: {err}");
        }
    }

    /// 增量语义（`update` 多次 + `digest()` 收尾）应与一次性等价——
    /// 对应酷狗 `java.security.MessageDigest` 的 update+digest 用法。
    #[test]
    fn test_incremental_matches_oneshot() {
        for algo in ["MD5", "SHA-256", "SHA-512"] {
            let data: Vec<u8> = b"the quick brown fox jumps over the lazy dog"
                .iter()
                .cycle()
                .take(200)
                .copied()
                .collect();
            // 分三段累积喂入（模拟 update+digest 增量路径）
            let mut acc: Vec<u8> = Vec::new();
            acc.extend_from_slice(&data[..80]);
            acc.extend_from_slice(&data[80..160]);
            acc.extend_from_slice(&data[160..]);
            let oneshot = digest_bytes(algo, &data).unwrap();
            let stepped = digest_bytes(algo, &acc).unwrap();
            assert_eq!(oneshot, stepped, "{algo} 增量累积应与一次性摘要一致");
        }
    }
}
