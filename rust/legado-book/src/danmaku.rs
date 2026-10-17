//! B 站弹幕 XML 纯解析；保留契约 §2.50 的原始结果和容错语义。

// ─── §2.50 B 站弹幕 XML 解析（纯函数，无 IO） ──────────────────────────────
//
// 对齐原版 `help/gsyVideo/BiliDanmukuParser.kt`（SAX）：
// - `<d p="时间秒,类型,字号,颜色,时间戳,池,hash,id">文本</d>`（:80-89）；
// - `time = (p0.toFloat() * 1000).toLong()`（:95，f32 乘后截断）；
// - `color = ((0xFF000000 | p3) & 0xFFFFFFFF).toInt()`（:99，有符号 ARGB）；
// - 字号原值透传（density 换算归 Dart 渲染层，契约 §2.50）；
// - 文本先经 XML 实体解码（SAX characters），再套 `decodeXmlString` 四实体
//   （:257-272）——即 `&amp;quot;` 这类双重转义会被还原两层；
// - 类型映射（DanmakuFlameMaster 0.9.25 `DanmakuFactory` 字节码）：
//   1 右→左 / 4 底 / 5 顶 / 6 左→右 / 7 special；2/3/8 及范围外静默丢弃；
// - type7 高级弹幕：先校验文本为 JSON 数组且 `[4]` 为非空字符串（:136-253，
//   失败即丢弃），通过后**保留 JSON 原文**于 `text`（V-B2 渲染边界：数据保留、
//   不渲染，供后续批次消费）；
// - 失败语义：空 / 非 XML / XML 文档级错误（畸形、实体未定义、多根）→ None，
//   对齐原版 SAX 失败→null；合法 XML 但无有效弹幕 → `[]`（原版返回空 Danmakus）。
//
// 有意登记的安全偏离：原版对单行畸形 `p`（缺属性 / 字段＜4 / 非数字）会抛
// 运行时异常（SAX 回调未捕获，原版表现为崩溃/未定义）；我方宿主安全语义为
// **跳过该行并继续解析**，其余行不受影响（不 panic、不整体失败）。
// 结果按 timeMs 稳定升序（契约 §2.50；同刻保持文档序）。

/// 保留的弹幕类型（对齐 0.9.25 `DanmakuFactory.createDanmaku` 字节码）
const DANMAKU_TYPES_KEPT: [i32; 5] = [1, 4, 5, 6, 7];

/// 契约 §2.50 解析结果项（JSON 字段名与契约逐字对齐）
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
struct DanmakuItem {
    #[serde(rename = "timeMs")]
    time_ms: i64,
    #[serde(rename = "type")]
    danmaku_type: i32,
    #[serde(rename = "textSizeRaw")]
    text_size_raw: f64,
    color: i32,
    text: String,
}

/// 解析 `p` 属性 → (timeMs, type, textSizeRaw, color)；字段不足/非数字 → None
///
/// 数值口径对齐 Kotlin：浮点字段（p0/p2）允许首尾空白（Java parseFloat 语义），
/// 整型字段（p1/p3）不允许空白（Java parseInt/parseLong 语义）。
fn parse_p_attribute(p: &str) -> Option<(i64, i32, f64, i32)> {
    // Kotlin：split(",").dropLastWhile { it.isEmpty() }
    let mut parts: Vec<&str> = p.split(',').collect();
    while parts.last().is_some_and(|s| s.is_empty()) {
        parts.pop();
    }
    if parts.len() < 4 {
        return None;
    }
    let time = (parts[0].trim().parse::<f32>().ok()? * 1000.0) as i64;
    let danmaku_type = parts[1].parse::<i32>().ok()?;
    let text_size_raw = parts[2].trim().parse::<f32>().ok()? as f64;
    let raw_color = parts[3].parse::<i64>().ok()?;
    let color = ((0xFF00_0000_i64 | raw_color) & 0xFFFF_FFFF) as i32;
    Some((time, danmaku_type, text_size_raw, color))
}

/// 对齐原版 `decodeXmlString`（:257-272）：仅四实体、顺序 amp→quot→gt→lt
fn decode_xml_string(raw: &str) -> String {
    if !(raw.contains("&amp;")
        || raw.contains("&quot;")
        || raw.contains("&gt;")
        || raw.contains("&lt;"))
    {
        return raw.to_string();
    }
    raw.replace("&amp;", "&")
        .replace("&quot;", "\"")
        .replace("&gt;", ">")
        .replace("&lt;", "<")
}

/// 展开 quick-xml 0.42 的 GeneralRef 事件（SAX characters 已解码语义）
///
/// 支持十进制/十六进制字符引用与五个预定义实体；未定义实体返回 None
/// （原版 SAX 对未定义实体报致命错误 → 整体 null）。
fn resolve_general_ref(name: &str) -> Option<char> {
    if let Some(number) = name.strip_prefix('#') {
        let code = match number.strip_prefix(['x', 'X']) {
            Some(hex) => u32::from_str_radix(hex, 16).ok()?,
            None => number.parse::<u32>().ok()?,
        };
        return char::from_u32(code);
    }
    match name {
        "amp" => Some('&'),
        "lt" => Some('<'),
        "gt" => Some('>'),
        "quot" => Some('"'),
        "apos" => Some('\''),
        _ => None,
    }
}

/// 单条弹幕收尾：类型过滤 + type7 JSON 校验 + 文本二次实体解码
fn finalize_danmaku_item(
    p_fields: (i64, i32, f64, i32),
    text: Option<String>,
) -> Option<DanmakuItem> {
    let (time_ms, danmaku_type, text_size_raw, color) = p_fields;
    // 原版 endElement 要求 item.text != null（characters 至少触发一次）
    let text = decode_xml_string(&text?);
    if !DANMAKU_TYPES_KEPT.contains(&danmaku_type) {
        return None;
    }
    if danmaku_type == 7 {
        // 高级弹幕：文本须为 JSON 数组且 [4] 为非空字符串（对齐原版解析；失败丢弃）
        let trimmed = text.trim();
        if !(trimmed.starts_with('[') && trimmed.ends_with(']')) {
            return None;
        }
        let array: Vec<serde_json::Value> = serde_json::from_str(trimmed).ok()?;
        let display_text = array.get(4)?.as_str()?;
        if display_text.is_empty() {
            return None;
        }
        // 保留 JSON 属性原文（渲染边界：V-B2 不渲染 type7）
        return Some(DanmakuItem {
            time_ms,
            danmaku_type,
            text_size_raw,
            color,
            text: trimmed.to_string(),
        });
    }
    Some(DanmakuItem {
        time_ms,
        danmaku_type,
        text_size_raw,
        color,
        text,
    })
}

/// 解析 B 站弹幕 XML 为契约 §2.50 JSON 数组
///
/// 纯函数：无 IO、无 DB、无 panic 路径。`None` = 空/非 XML/文档级解析失败；
/// `Some("[]")` = 合法 XML 但无有效弹幕项。
pub fn parse_video_danmaku(raw: &str) -> Option<String> {
    // UTF-8 BOM（Android InputSource 可吞，quick-xml 视为内容 → 先剥离）
    let content = raw.strip_prefix('\u{feff}').unwrap_or(raw);
    if content.trim().is_empty() {
        return None;
    }

    let mut reader = quick_xml::Reader::from_str(content);
    let mut items: Vec<DanmakuItem> = Vec::new();
    let mut depth: usize = 0;
    let mut root_count: usize = 0;
    // 当前 <d> 的 p 字段与所在深度（None = 不在有效 d 内）
    let mut current_fields: Option<(i64, i32, f64, i32)> = None;
    let mut current_depth: usize = 0;
    let mut current_text: Option<String> = None;

    loop {
        match reader.read_event() {
            Err(_) => return None,
            Ok(quick_xml::events::Event::Eof) => break,
            Ok(quick_xml::events::Event::Start(e)) => {
                if depth == 0 {
                    root_count += 1;
                }
                depth += 1;
                let is_d = e.local_name().as_ref().eq_ignore_ascii_case("d");
                if is_d && current_fields.is_none() {
                    let mut p_value: Option<String> = None;
                    for attr in e.attributes() {
                        let Ok(attr) = attr else { return None };
                        if attr.key.as_ref() == "p" {
                            match attr.normalized_value(quick_xml::XmlVersion::Explicit1_0) {
                                Ok(v) => p_value = Some(v.into_owned()),
                                Err(_) => return None,
                            }
                        }
                    }
                    // 缺 p / p 畸形：原版抛异常（未定义）；我方跳过该行（登记偏离）
                    current_fields = p_value.as_deref().and_then(parse_p_attribute);
                    current_depth = depth;
                    current_text = None;
                }
            }
            Ok(quick_xml::events::Event::Empty(_)) => {
                if depth == 0 {
                    root_count += 1;
                }
                // <d .../>：无文本（原版 characters 未触发 → text==null → 丢弃）
            }
            Ok(quick_xml::events::Event::End(_)) => {
                if current_fields.is_some() && depth == current_depth {
                    let item =
                        finalize_danmaku_item(current_fields.take().unwrap(), current_text.take());
                    if let Some(item) = item {
                        items.push(item);
                    }
                }
                depth = depth.saturating_sub(1);
            }
            Ok(quick_xml::events::Event::Text(e)) => {
                if depth == 0 {
                    if !e.as_ref().trim().is_empty() {
                        return None;
                    }
                } else if current_fields.is_some() {
                    current_text
                        .get_or_insert_with(String::new)
                        .push_str(e.as_ref());
                }
            }
            Ok(quick_xml::events::Event::CData(e)) => {
                if depth == 0 {
                    if !e.as_ref().trim().is_empty() {
                        return None;
                    }
                } else if current_fields.is_some() {
                    current_text
                        .get_or_insert_with(String::new)
                        .push_str(e.as_ref());
                }
            }
            Ok(quick_xml::events::Event::GeneralRef(r)) => {
                // 未定义实体 = XML 文档级失败（对齐原版 SAX 致命错误 → null）
                let resolved = resolve_general_ref(r.as_ref())?;
                if current_fields.is_some() {
                    current_text.get_or_insert_with(String::new).push(resolved);
                }
            }
            Ok(_) => {}
        }
    }

    // 要求恰一个顶层元素：空文档 / 纯文本 / 多根 → None（对齐 SAX 文档语义）
    if root_count != 1 {
        return None;
    }
    // 契约 §2.50：按 timeMs 升序（稳定排序保持同刻文档序）
    items.sort_by_key(|item| item.time_ms);
    serde_json::to_string(&items).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    // ─── §2.50 parse_video_danmaku（纯函数）测试 ────────────────────────

    /// 解析输出 → JSON 数组（测试断言辅助）
    fn parse_items(raw: &str) -> Vec<serde_json::Value> {
        let json = parse_video_danmaku(raw).expect("应为可解析 XML");
        serde_json::from_str(&json).expect("输出应为 JSON 数组")
    }

    /// 四类弹幕（1 右→左 / 5 顶 / 4 底 / 6 左→右）字段逐项 + 按 timeMs 升序
    #[test]
    fn test_parse_video_danmaku_four_types() {
        // 文档序故意乱序：5(2s) / 6(1s) / 1(0.5s) / 4(3s)
        let xml = r#"<i>
            <d p="2.0,5,25,16711680">顶部</d>
            <d p="1.0,6,18,65280">左到右</d>
            <d p="0.5,1,25,16777215">右到左</d>
            <d p="3.0,4,36,255">底部</d>
        </i>"#;
        let items = parse_items(xml);
        assert_eq!(items.len(), 4, "四类弹幕均应保留: {items:?}");
        // 升序：0.5s(右到左) / 1s(左到右) / 2s(顶部) / 3s(底部)
        assert_eq!(items[0]["timeMs"], 500);
        assert_eq!(items[0]["type"], 1);
        assert_eq!(items[0]["textSizeRaw"], 25.0);
        assert_eq!(items[0]["color"], -1); // 0xFFFFFFFF as i32
        assert_eq!(items[0]["text"], "右到左");

        assert_eq!(items[1]["timeMs"], 1000);
        assert_eq!(items[1]["type"], 6);
        assert_eq!(items[1]["textSizeRaw"], 18.0);
        assert_eq!(items[1]["color"], 0xFF00FF00u32 as i32);
        assert_eq!(items[1]["text"], "左到右");

        assert_eq!(items[2]["type"], 5);
        assert_eq!(items[2]["color"], 0xFFFF0000u32 as i32);
        assert_eq!(items[2]["text"], "顶部");
        assert_eq!(items[3]["type"], 4);
        assert_eq!(items[3]["color"], 0xFF0000FFu32 as i32);
        assert_eq!(items[3]["text"], "底部");
    }

    /// p 属性各段口径：f32 乘 1000 截断、颜色有符号 ARGB、字号原值透传
    #[test]
    fn test_parse_video_danmaku_p_attribute_segments() {
        // 0.001 的 f32 表示略大于 0.001 → *1000 截断为 1（Kotlin Float 同口径）
        let xml = r#"<i><d p="0.001,1,25.5,0">a</d><d p="2.5,1,25,-1">b</d></i>"#;
        let items = parse_items(xml);
        assert_eq!(items.len(), 2, "{items:?}");
        assert_eq!(items[0]["timeMs"], 1);
        assert_eq!(items[0]["textSizeRaw"], 25.5);
        assert_eq!(items[0]["color"], -16777216); // p3=0 → 0xFF000000 as i32
        assert_eq!(items[1]["timeMs"], 2500);
        assert_eq!(items[1]["color"], -1); // p3=-1 → 0xFFFFFFFF as i32
        // 尾部空段（p 以逗号结尾）按 Kotlin dropLastWhile 丢弃
        let xml_tail = r#"<i><d p="1.5,1,25,16777215,1422201084,0,hash,id,">尾部逗号</d></i>"#;
        let items = parse_items(xml_tail);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0]["timeMs"], 1500);
    }

    /// type 2/3/8 及范围外类型静默丢弃（对齐 DanmakuFactory 字节码）
    #[test]
    fn test_parse_video_danmaku_drops_unsupported_types() {
        let xml = r#"<i>
            <d p="1,2,25,0">类型2</d>
            <d p="2,3,25,0">类型3</d>
            <d p="3,8,25,0">类型8</d>
            <d p="4,0,25,0">类型0</d>
            <d p="5,9,25,0">类型9</d>
            <d p="6,1,25,0">类型1保留</d>
        </i>"#;
        let items = parse_items(xml);
        assert_eq!(items.len(), 1, "仅 type1 应保留: {items:?}");
        assert_eq!(items[0]["type"], 1);
        assert_eq!(items[0]["text"], "类型1保留");
    }

    /// type7 高级弹幕：合法 JSON 数组且 [4] 非空 → 保留 JSON 原文；
    /// 非数组 / JSON 非法 / 元素不足 / [4] 空 → 丢弃（对齐原版 :136-253）
    #[test]
    fn test_parse_video_danmaku_type7_json() {
        // 合法高级弹幕（B 站格式为字符串数组，alpha 为 "起-止" 形式）
        let valid =
            r#"<i><d p="1,7,25,16777215">["0.1","0.2","0.8-1","4.5","高级文本","0","0"]</d></i>"#;
        let items = parse_items(valid);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0]["type"], 7);
        assert_eq!(
            items[0]["text"], "[\"0.1\",\"0.2\",\"0.8-1\",\"4.5\",\"高级文本\",\"0\",\"0\"]",
            "type7 应保留 JSON 属性原文（V-B2 不渲染，登记边界）"
        );

        // 非法用例：非 JSON 数组 / 元素不足 5 / [4] 为空串 / [4] 非字符串
        for bad in [
            r#"<i><d p="1,7,25,0">高级弹幕不是JSON</d></i>"#,
            r#"<i><d p="1,7,25,0">["0.1","0.2","0.8","4.5"]</d></i>"#,
            r#"<i><d p="1,7,25,0">["0.1","0.2","0.8","4.5","","0","0"]</d></i>"#,
            r#"<i><d p="1,7,25,0">["0.1","0.2","0.8","4.5",42,"0","0"]</d></i>"#,
            r#"<i><d p="1,7,25,0">[0.1,0.2,0.8-1,4.5,42]</d></i>"#,
        ] {
            assert!(parse_items(bad).is_empty(), "非法 type7 应丢弃: {bad}");
        }
    }

    /// 畸形行容错（登记的安全偏离）：缺 p / 字段＜4 / 非数字 → 跳过该行，
    /// 其余行继续解析；文档级 XML 错误才整体 null
    #[test]
    fn test_parse_video_danmaku_malformed_rows_skipped() {
        let xml = r#"<i>
            <d>缺p属性</d>
            <d p="1,1">字段不足</d>
            <d p="abc,1,25,0">时间非数字</d>
            <d p="1,abc,25,0">类型非数字</d>
            <d p="1,1,abc,0">字号非数字</d>
            <d p="1,1,25,abc">颜色非数字</d>
            <d p="2,1,25,0"></d>
            <d p="3,1,25,0"/>
            <d p="4,1,25,0">有效行</d>
        </i>"#;
        let items = parse_items(xml);
        assert_eq!(items.len(), 1, "仅有效行应保留: {items:?}");
        assert_eq!(items[0]["timeMs"], 4000);
        assert_eq!(items[0]["text"], "有效行");
    }

    /// XML 实体解码：SAX 一层 + decodeXmlString 四实体第二层（双重转义还原）
    #[test]
    fn test_parse_video_danmaku_entity_decoding() {
        let xml = r#"<i>
            <d p="1,1,25,0">A&amp;B</d>
            <d p="2,1,25,0">&lt;tag&gt; &quot;q&quot;</d>
            <d p="3,1,25,0">&#65;&#x42;</d>
            <d p="4,1,25,0">&amp;quot;双重转义&amp;quot;</d>
            <d p="5,1,25,0">apos保持&apos;原样</d>
        </i>"#;
        let items = parse_items(xml);
        assert_eq!(items.len(), 5, "{items:?}");
        assert_eq!(items[0]["text"], "A&B");
        assert_eq!(items[1]["text"], "<tag> \"q\"");
        assert_eq!(items[2]["text"], "AB");
        // 原版：SAX 解码 &amp;quot; → &quot;，decodeXmlString 再解 → "
        assert_eq!(items[3]["text"], "\"双重转义\"");
        // 原版 decodeXmlString 不含 apos：SAX 解为 ' 后不再处理 → 保持 '
        assert_eq!(items[4]["text"], "apos保持'原样");
    }

    /// 非法文档 / 空 / 多根 / 未闭合 / 未定义实体 → None；合法空 XML → "[]"
    #[test]
    fn test_parse_video_danmaku_invalid_documents() {
        assert_eq!(parse_video_danmaku(""), None, "空串应 None");
        assert_eq!(parse_video_danmaku("   \n"), None, "空白应 None");
        assert_eq!(parse_video_danmaku("not xml"), None, "纯文本应 None");
        assert_eq!(
            parse_video_danmaku("hello<d p=\"1,1,25,0\">a</d>"),
            None,
            "根前非空白文本应 None"
        );
        assert_eq!(
            parse_video_danmaku("<d p=\"1,1,25,0\">a</d><d p=\"2,1,25,0\">b</d>"),
            None,
            "多根应 None"
        );
        assert_eq!(
            parse_video_danmaku("<i><d p=\"1,1,25,0\">a</i>"),
            None,
            "未闭合应 None"
        );
        assert_eq!(
            parse_video_danmaku("<i><d p=\"1,1,25,0\">a&foo;b</d></i>"),
            None,
            "未定义实体应 None（对齐 SAX 致命错误）"
        );
        assert_eq!(
            parse_video_danmaku("<i/>").as_deref(),
            Some("[]"),
            "合法空 XML 应返回空数组（原版返回空 Danmakus）"
        );
        assert_eq!(
            parse_video_danmaku("<i><chatserver>xx</chatserver></i>").as_deref(),
            Some("[]"),
            "无 d 元素应返回空数组"
        );
        // BOM 前缀（Android InputSource 可吞）应可解析
        let with_bom = "\u{feff}<i><d p=\"1,1,25,0\">bom</d></i>";
        assert_eq!(parse_items(with_bom).len(), 1);
    }

    /// 同刻稳定序：timeMs 相同保持文档序；CDATA 与注释不影响文本拼接
    #[test]
    fn test_parse_video_danmaku_order_and_cdata() {
        let xml = r#"<i>
            <d p="2.0,1,25,0">后</d>
            <d p="1.0,1,25,0">A<!--注释-->B</d>
            <d p="1.0,1,25,0"><![CDATA[CD&ATA]]></d>
        </i>"#;
        let items = parse_items(xml);
        assert_eq!(items.len(), 3);
        assert_eq!(items[0]["text"], "AB");
        assert_eq!(items[1]["text"], "CD&ATA");
        assert_eq!(items[2]["text"], "后");
        assert_eq!(items[0]["timeMs"], items[1]["timeMs"]);
    }
}
