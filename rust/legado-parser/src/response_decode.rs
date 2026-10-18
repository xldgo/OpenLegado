//! 抓取链与脚本网络共用的响应编码检测，不执行网络请求。
use crate::AnalyzeUrl;
use chardetng::{EncodingDetector, Iso2022JpDetection, Utf8Detection};
use encoding_rs::Encoding;
use std::collections::HashMap;

/// 四级响应解码：显式 charset → Content-Type 头 → HTML meta → 统计探测
///
/// 前三级对齐原版 OkHttpUtils.ResponseBody.text：`explicit`（UrlOption.charset）
/// 最高优先，随后 `contentType()?.charset()`，再 `EncodingDetect.getHtmlEncode`
/// 的 meta 扫描；第四级对齐其 meta 无果后的 ICU4J `CharsetDetector` 统计探测
/// （探测失败回 UTF-8，见 [`decode_detected_or_lossy`]）。
///
/// `pub`（HTTP P2-19 尾项）：抓取链与搜索链
/// （搜索适配）共用本入口——探测实现仅此一处，避免双份代码。
/// 显式 charset 优先级不回退：头/meta/探测均不可能覆盖 `explicit`。
pub fn decode_web_response(
    bytes: &[u8],
    headers: &HashMap<String, String>,
    explicit: Option<&str>,
) -> String {
    let charset = explicit
        .filter(|s| !s.trim().is_empty())
        .map(str::to_string)
        .or_else(|| charset_from_content_type(headers))
        .or_else(|| charset_from_html_meta(bytes));
    match charset {
        // 前三级：按声明编码解码（未知标签在 decode_response_bytes 内回退 UTF-8）
        Some(charset) => AnalyzeUrl::decode_response_bytes(bytes, Some(&charset)),
        // 第四级：统计探测；探测为 UTF-8 / 无损解码失败 → 既有 lossy UTF-8 兜底
        None => decode_detected_or_lossy(bytes),
    }
}

/// 第四级自动探测解码（chardetng：encoding_rs 同作者的纯 Rust 探测器）
///
/// - TLD hint 传 `None`（对齐上游无域名线索口径）；
/// - `Utf8Detection::Allow`：上游 ICU4J 对合法 UTF-8 会检出 UTF-8；若按浏览器
///   规则 `Deny` 会把无标识的中文 UTF-8 页误判为 windows-1252（乱码回归）；
/// - ISO-2022-JP 按 chardetng 对可执行脚本的 Web 内容指引设 `Deny`；
/// - 含 BOM：BOM 直接决定编码并去 BOM 后解码（对齐上游
///   `Utf8BomUtils.removeUTF8BOM`，顺带支持标准 UTF-16 BOM 嗅探）；
/// - 无 BOM：探测结果非 UTF-8 时走 encoding_rs 无损 API
///   （`decode_without_bom_handling_and_without_replacement`，不注入替换字符）；
///   chardetng 不暴露置信度接口，故不设置信阈值（对齐上游无阈值）——无损解码
///   失败（探测结果与字节不符）即视为探测失败，回 lossy UTF-8；猜测为 UTF-8
///   同样交回 lossy UTF-8，保证既有 UTF-8 页行为逐字不变。
/// - 已知边界（P2-19 尾项审查 P2-2）：猜中 GBK/GB18030 族时无损 API 对混合
///   非法字节几乎总成功（GBK 码位覆盖极广），个别乱码正文会以有损结果进入
///   规则解析——与上游「无置信阈值」口径一致的选择；JSON 等纯 ASCII 响应
///   不受影响（UTF-8 猜测直接走 lossy UTF-8，ASCII 解码逐字一致）。
fn decode_detected_or_lossy(bytes: &[u8]) -> String {
    if let Some((encoding, bom_len)) = Encoding::for_bom(bytes) {
        // BOM 权威：decode_without_bom_handling 为有损替换解码（对齐上游
        // `String(bytes, Charset.forName(BOM 编码))`）
        return encoding
            .decode_without_bom_handling(&bytes[bom_len..])
            .0
            .into_owned();
    }

    let mut detector = EncodingDetector::new(Iso2022JpDetection::Deny);
    let _ = detector.feed(bytes, true);
    let guessed = detector.guess(None, Utf8Detection::Allow);
    if guessed == encoding_rs::UTF_8 {
        return String::from_utf8_lossy(bytes).into_owned();
    }
    match guessed.decode_without_bom_handling_and_without_replacement(bytes) {
        Some(decoded) => decoded.into_owned(),
        None => String::from_utf8_lossy(bytes).into_owned(),
    }
}

fn charset_from_content_type(headers: &HashMap<String, String>) -> Option<String> {
    let value = headers
        .iter()
        .find(|(name, _)| name.eq_ignore_ascii_case("content-type"))
        .map(|(_, value)| value.as_str())?;
    extract_charset_assignment(value)
}

fn extract_charset_assignment(value: &str) -> Option<String> {
    let lower = value.to_ascii_lowercase();
    let start = lower.find("charset")? + 7;
    let tail = &value[start..];
    let equal = tail.find('=')?;
    let value = tail[equal + 1..].trim();
    let value = value.trim_start_matches(['"', '\'']);
    let charset = value.split([';', ' ', '"', '\'']).next().unwrap_or("");
    (!charset.is_empty()).then(|| charset.to_string())
}

pub fn charset_from_html_meta(bytes: &[u8]) -> Option<String> {
    let head = String::from_utf8_lossy(&bytes[..bytes.len().min(16 * 1024)]);
    let meta_re = regex::Regex::new(r##"(?is)<meta\b[^>]*>"##).ok()?;
    let attr_re = regex::Regex::new(
        r##"(?is)([a-z_:][a-z0-9_:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>]+))"##,
    )
    .ok()?;
    for tag in meta_re.find_iter(&head).map(|m| m.as_str()) {
        let mut attrs: HashMap<String, String> = HashMap::new();
        for caps in attr_re.captures_iter(tag) {
            let name = caps
                .get(1)
                .map(|m| m.as_str().to_ascii_lowercase())
                .unwrap_or_default();
            let value = caps
                .get(2)
                .or_else(|| caps.get(3))
                .or_else(|| caps.get(4))
                .map(|m| m.as_str().to_string())
                .unwrap_or_default();
            attrs.insert(name, value);
        }
        if let Some(charset) = attrs.get("charset").filter(|v| !v.trim().is_empty()) {
            return Some(charset.trim().to_string());
        }
        let is_content_type = attrs
            .get("http-equiv")
            .is_some_and(|v| v.eq_ignore_ascii_case("content-type"));
        if is_content_type
            && let Some(cs) = attrs
                .get("content")
                .and_then(|v| extract_charset_assignment(v))
        {
            return Some(cs);
        }
    }
    None
}
