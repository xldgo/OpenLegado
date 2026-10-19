//! 字体反混淆：纯解析结果由Arc持有，资源缓存仅保留4项；不重载JSON句柄或磁盘字体。
//! — Codex + Bridge

use crate::host_api::query_ttf::QueryTtf;
use std::sync::{Arc, Mutex};

const FONT_LRU_CAPACITY: usize = 4;
#[derive(Default)]
pub struct FontResources {
    lru: Mutex<Vec<(String, Arc<QueryTtf>)>>,
}
pub type FontDownloader<'a> = dyn Fn(&str) -> Result<Vec<u8>, String> + 'a;

fn sha256_hex(data: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    format!("{:x}", Sha256::digest(data))
}

/// 不按UTF-8字节边界切片；与上游isAbsUrl一样忽略HTTP(S)大小写。
pub(crate) fn is_remote(data: &str) -> bool {
    data.get(..7)
        .is_some_and(|s| s.eq_ignore_ascii_case("http://"))
        || data
            .get(..8)
            .is_some_and(|s| s.eq_ignore_ascii_case("https://"))
}

impl FontResources {
    fn lru_get(cache: &mut Vec<(String, Arc<QueryTtf>)>, key: &str) -> Option<Arc<QueryTtf>> {
        let index = cache.iter().position(|(k, _)| k == key)?;
        let entry = cache.remove(index);
        let font = entry.1.clone();
        cache.insert(0, entry);
        Some(font)
    }
    fn load(
        &self,
        key: String,
        use_cache: bool,
        load: impl FnOnce() -> Result<Vec<u8>, String>,
    ) -> Result<Arc<QueryTtf>, String> {
        crate::cancellation::check().map_err(|e| e.to_string())?;
        if use_cache
            && let Some(font) = Self::lru_get(
                &mut self.lru.lock().unwrap_or_else(|p| p.into_inner()),
                &key,
            )
        {
            return Ok(font);
        }
        // 网络与当前VM规则求值均在锁外；不通过静态表或磁盘持有额外引用。
        let bytes = load()?;
        crate::cancellation::check().map_err(|e| e.to_string())?;
        let font = Arc::new(QueryTtf::parse(&bytes).map_err(|error| error.to_string())?);
        crate::cancellation::check().map_err(|e| e.to_string())?;
        if use_cache {
            let mut cache = self.lru.lock().unwrap_or_else(|p| p.into_inner());
            if let Some(existing) = Self::lru_get(&mut cache, &key) {
                return Ok(existing);
            }
            cache.insert(0, (key, font.clone()));
            cache.truncate(FONT_LRU_CAPACITY);
        }
        Ok(font)
    }
    /// 字符串只解析URL规则或Base64；本地扩展由JS边界校验授权、路径后传入字节。
    pub fn query_ttf(
        &self,
        download: &FontDownloader<'_>,
        data: &str,
        use_cache: bool,
    ) -> Result<Arc<QueryTtf>, String> {
        self.load(sha256_hex(data.as_bytes()), use_cache, || {
            if is_remote(data) {
                download(data)
            } else {
                use base64::Engine;
                base64::engine::general_purpose::STANDARD
                    .decode(data.trim())
                    .map_err(|e| format!("字体Base64解码失败: {e}"))
            }
        })
    }
    /// 字节视图已由JS边界复制，不保留引擎缓冲借用。
    pub fn query_bytes(&self, data: &[u8], use_cache: bool) -> Result<Arc<QueryTtf>, String> {
        self.load(sha256_hex(data), use_cache, || Ok(data.to_vec()))
    }
    /// 保持既有逐码点轮廓反查、空白及过滤规则；无IO，不会因LRU淘汰重新下载。
    pub fn replace_font(
        text: &str,
        error: Option<&QueryTtf>,
        correct: Option<&QueryTtf>,
        filter: bool,
    ) -> String {
        let (Some(error_font), Some(correct_font)) = (error, correct) else {
            return text.to_string();
        };
        let mut out = String::with_capacity(text.len());
        for ch in text.chars() {
            let code = ch as u32;
            // 忽略正常的空白字符
            if QueryTtf::is_blank_unicode(code) {
                out.push(ch);
                continue;
            }
            // 轮廓签名（错误字体）；glyphId 指向保留索引 0 时视为无轮廓
            let mut glyf = error_font.glyf_by_unicode(code).cloned();
            if error_font.glyf_id_by_unicode(code) == 0 {
                glyf = None;
            }
            if filter && glyf.is_none() {
                // 删除轮廓数据不存在的字符
                continue;
            }
            // 使用轮廓签名在正确字体反查 unicode
            if let Some(sig) = &glyf {
                let new_code = correct_font.unicode_by_glyf(sig);
                if new_code != 0
                    && let Some(new_ch) = char::from_u32(new_code)
                {
                    out.push(new_ch);
                    continue;
                }
            }
            // 无映射的字符保留原样
            out.push(ch);
        }
        out
    }
}

#[cfg(test)]
pub mod tests {
    use super::*;
    fn no_download(_: &str) -> Result<Vec<u8>, String> {
        panic!("此夹具不得触发下载")
    }

    /// cmap format 4 段描述（测试夹具用）
    pub struct Segment {
        pub start: u16,
        pub end: u16,
        pub id_delta: i16,
    }

    fn be16(v: u16) -> [u8; 2] {
        v.to_be_bytes()
    }

    fn be32(v: u32) -> [u8; 4] {
        v.to_be_bytes()
    }

    /// 构造 cmap 表（format 4，单平台记录）
    pub fn build_format4_cmap(segments: &[Segment]) -> Vec<u8> {
        let seg_count = segments.len() + 1; // 附加终止段 [0xFFFF, 0xFFFF]
        let mut sub = Vec::new();
        sub.extend_from_slice(&be16(4)); // format
        let length = 16 + seg_count * 8;
        sub.extend_from_slice(&be16(length as u16));
        sub.extend_from_slice(&be16(0)); // language
        sub.extend_from_slice(&be16((seg_count * 2) as u16)); // segCountX2
        sub.extend_from_slice(&be16(0)); // searchRange
        sub.extend_from_slice(&be16(0)); // entrySelector
        sub.extend_from_slice(&be16(0)); // rangeShift
        for seg in segments {
            sub.extend_from_slice(&be16(seg.end));
        }
        sub.extend_from_slice(&be16(0xFFFF));
        sub.extend_from_slice(&be16(0)); // reservedPad
        for seg in segments {
            sub.extend_from_slice(&be16(seg.start));
        }
        sub.extend_from_slice(&be16(0xFFFF));
        for seg in segments {
            sub.extend_from_slice(&seg.id_delta.to_be_bytes());
        }
        sub.extend_from_slice(&be16(1)); // 终止段 delta
        for _ in 0..seg_count {
            sub.extend_from_slice(&be16(0)); // idRangeOffset 全 0
        }

        let mut cmap = Vec::new();
        cmap.extend_from_slice(&be16(0)); // version
        cmap.extend_from_slice(&be16(1)); // numTables
        cmap.extend_from_slice(&be16(3)); // platformID = Windows
        cmap.extend_from_slice(&be16(1)); // encodingID = Unicode BMP
        cmap.extend_from_slice(&be32(12)); // subtable offset
        cmap.extend_from_slice(&sub);
        cmap
    }

    /// 简单字形轮廓数据（3 点三角，坐标随变体区分）
    fn simple_glyph_bytes(variant: u8) -> Vec<u8> {
        let mut g = Vec::new();
        g.extend_from_slice(&be16(1)); // numberOfContours
        g.extend_from_slice(&be16(0)); // xMin
        g.extend_from_slice(&be16(0)); // yMin
        g.extend_from_slice(&be16(10)); // xMax
        g.extend_from_slice(&be16(10)); // yMax
        g.extend_from_slice(&be16(2)); // endPtsOfContours = [2]
        g.extend_from_slice(&be16(0)); // instructionLength
        // flags：3 点，短向量正号（x: 0x12, y: 0x24）
        g.extend_from_slice(&[0x12 | 0x24, 0x12 | 0x24, 0x12 | 0x24]);
        let d = variant;
        g.extend_from_slice(&[1 + d, 2 + d, 3 + d]); // x 增量
        g.extend_from_slice(&[4 + d, 5 + d, 6 + d]); // y 增量
        g
    }

    /// 复合字形数据（引用 glyph 3，单组件无缩放）
    fn composite_glyph_bytes() -> Vec<u8> {
        let mut g = Vec::new();
        g.extend_from_slice(&0xFFFFu16.to_be_bytes()); // numberOfContours = -1
        g.extend_from_slice(&be16(0)); // xMin
        g.extend_from_slice(&be16(0)); // yMin
        g.extend_from_slice(&be16(10)); // xMax
        g.extend_from_slice(&be16(10)); // yMax
        g.extend_from_slice(&be16(0b01)); // flags：16 位无符号参数，无后续组件
        g.extend_from_slice(&be16(3)); // glyphIndex
        g.extend_from_slice(&be16(2)); // arg1
        g.extend_from_slice(&be16(3)); // arg2
        g
    }

    /// 构造最小可用 TTF（head / maxp / cmap / loca / glyf / name）
    ///
    /// - glyph 0：.notdef（空）
    /// - glyph 1：`composite=true` 时为复合字形，否则为变体 0 简单字形
    /// - glyph 2/3：变体 1/2 简单字形（glyph 3 同时作为复合组件引用目标）
    /// - cmap 段由 `segments` 指定
    pub fn build_minimal_ttf(segments: &[Segment], composite: bool) -> Vec<u8> {
        let cmap = build_format4_cmap(segments);

        // glyf：glyph0 空、glyph1、glyph2、glyph3（字形数据需偶数对齐，loca Offset16 才不截断）
        let g1 = if composite {
            composite_glyph_bytes()
        } else {
            let mut g = simple_glyph_bytes(0);
            if !g.len().is_multiple_of(2) {
                g.push(0);
            }
            g
        };
        let mut g2 = simple_glyph_bytes(1);
        if !g2.len().is_multiple_of(2) {
            g2.push(0);
        }
        let mut g3 = simple_glyph_bytes(2);
        if !g3.len().is_multiple_of(2) {
            g3.push(0);
        }
        let off1 = 0usize;
        let off2 = off1 + g1.len();
        let off3 = off2 + g2.len();
        let off_end = off3 + g3.len();
        let mut glyf = Vec::new();
        glyf.extend_from_slice(&g1);
        glyf.extend_from_slice(&g2);
        glyf.extend_from_slice(&g3);

        // loca（Offset16，值需 /2 存储；glyph0 无数据：0,0）
        let mut loca = Vec::new();
        for &off in &[0usize, off1 / 2, off2 / 2, off3 / 2, off_end / 2] {
            loca.extend_from_slice(&be16(off as u16));
        }

        // head（54 字节）
        let mut head = vec![0u8; 54];
        head[0..4].copy_from_slice(&be32(0x00010000)); // sfntVersion
        head[12..16].copy_from_slice(&be32(0x5F0F3CF5)); // magicNumber
        head[16..18].copy_from_slice(&be16(0)); // flags
        head[18..20].copy_from_slice(&be16(1000)); // unitsPerEm
        head[36..38].copy_from_slice(&be16(10)); // xMax
        head[38..40].copy_from_slice(&be16(10)); // yMax
        head[50..52].copy_from_slice(&be16(0)); // indexToLocFormat = Offset16

        // maxp
        let mut maxp = Vec::new();
        maxp.extend_from_slice(&be32(0x00010000)); // version
        maxp.extend_from_slice(&be16(4)); // numGlyphs
        maxp.extend_from_slice(&be16(3)); // maxPoints
        maxp.extend_from_slice(&be16(1)); // maxContours
        maxp.extend_from_slice(&[0u8; 22]); // 其余字段置 0

        // name（空记录）
        let mut name = Vec::new();
        name.extend_from_slice(&be16(0)); // format
        name.extend_from_slice(&be16(0)); // count
        name.extend_from_slice(&be16(6)); // stringOffset

        // 组装：表按 tag 字母序（cmap, glyf, head, loca, maxp, name）
        let entries: [(&[u8; 4], &Vec<u8>); 6] = [
            (b"cmap", &cmap),
            (b"glyf", &glyf),
            (b"head", &head),
            (b"loca", &loca),
            (b"maxp", &maxp),
            (b"name", &name),
        ];
        let header_len = 12 + entries.len() * 16;
        let mut offset = header_len;
        let mut offsets: Vec<usize> = Vec::new();
        for (_, data) in &entries {
            offsets.push(offset);
            offset += (data.len() + 3) & !3; // 4 字节对齐
        }

        let mut out = Vec::new();
        out.extend_from_slice(&be32(0x00010000)); // sfntVersion
        out.extend_from_slice(&be16(entries.len() as u16)); // numTables
        out.extend_from_slice(&be16(0)); // searchRange
        out.extend_from_slice(&be16(0)); // entrySelector
        out.extend_from_slice(&be16(0)); // rangeShift
        for (i, (tag, data)) in entries.iter().enumerate() {
            out.extend_from_slice(*tag);
            out.extend_from_slice(&be32(0)); // checkSum（解析不校验）
            out.extend_from_slice(&be32(offsets[i] as u32));
            out.extend_from_slice(&be32(data.len() as u32));
        }
        for (i, (_, data)) in entries.iter().enumerate() {
            out.extend_from_slice(data);
            let pad = (4 - (data.len() % 4)) % 4;
            out.extend_from_slice(&vec![0u8; pad]);
            debug_assert_eq!(out.len(), offsets[i] + ((data.len() + 3) & !3));
        }
        out
    }

    /// 错误字体 base64（PUA E001..E003 → glyph 1..3，delta 取模运算正值）
    fn error_font_b64() -> String {
        use base64::Engine;
        let font = build_minimal_ttf(
            &[Segment {
                start: 0xE001,
                end: 0xE003,
                id_delta: 0x2000, // E001 + 0x2000 = 0x10001，& 0xFFFF = 1
            }],
            false,
        );
        base64::engine::general_purpose::STANDARD.encode(&font)
    }

    /// 正确字体 base64（'A'..='C' → glyph 1..3）
    fn correct_font_b64() -> String {
        use base64::Engine;
        let font = build_minimal_ttf(
            &[Segment {
                start: 0x41,
                end: 0x43,
                id_delta: -0x40,
            }],
            false,
        );
        base64::engine::general_purpose::STANDARD.encode(&font)
    }

    #[test]
    fn test_query_ttf_empty() {
        assert!(
            FontResources::default()
                .query_ttf(&no_download, "", true)
                .is_err()
        );
    }
    #[test]
    fn test_query_ttf_base64_real_font() {
        let font = FontResources::default()
            .query_ttf(&no_download, &error_font_b64(), false)
            .unwrap();
        assert_eq!(font.glyf_id_by_unicode(0xE001), 1);
    }
    #[test]
    fn test_query_ttf_base64_invalid() {
        assert!(
            FontResources::default()
                .query_ttf(&no_download, "AAECAwQF", false)
                .is_err()
        );
    }
    #[test]
    fn test_query_ttf_cache_hit() {
        let fonts = FontResources::default();
        let one = fonts
            .query_ttf(&no_download, &error_font_b64(), true)
            .unwrap();
        let two = fonts
            .query_ttf(&no_download, &error_font_b64(), true)
            .unwrap();
        assert!(Arc::ptr_eq(&one, &two));
    }
    #[test]
    fn test_replace_font_null_handles() {
        assert_eq!(
            FontResources::replace_font("hello", None, None, false),
            "hello"
        );
    }

    #[test]
    fn test_replace_font_real_mapping() {
        let fonts = FontResources::default();
        // \uE001\uE002\uE003 → ABC（轮廓签名跨字体对齐）
        let err = fonts
            .query_ttf(&no_download, &error_font_b64(), true)
            .unwrap();
        let ok = fonts
            .query_ttf(&no_download, &correct_font_b64(), true)
            .unwrap();
        let text = "\u{E001}\u{E002}\u{E003}尾部";
        assert_eq!(
            FontResources::replace_font(text, Some(&err), Some(&ok), false),
            "ABC尾部"
        );
    }

    #[test]
    fn test_replace_font_multi_char_codepoint() {
        let fonts = FontResources::default();
        // 多字节码点（中文）不参与映射时保留原样，验证逐码点而非逐字节处理
        let err = fonts
            .query_ttf(&no_download, &error_font_b64(), true)
            .unwrap();
        let ok = fonts
            .query_ttf(&no_download, &correct_font_b64(), true)
            .unwrap();
        assert_eq!(
            FontResources::replace_font("第一章\u{E001}", Some(&err), Some(&ok), false),
            "第一章A"
        );
    }

    #[test]
    fn test_replace_font_unmapped_kept() {
        let fonts = FontResources::default();
        // 错误字体中不存在的字符保留原样
        let err = fonts
            .query_ttf(&no_download, &error_font_b64(), true)
            .unwrap();
        let ok = fonts
            .query_ttf(&no_download, &correct_font_b64(), true)
            .unwrap();
        assert_eq!(
            FontResources::replace_font("XYZ", Some(&err), Some(&ok), false),
            "XYZ"
        );
    }

    #[test]
    fn test_replace_font_filter_removes_unmapped() {
        let fonts = FontResources::default();
        // filter=true：错误字体中无轮廓的字符被删除
        let err = fonts
            .query_ttf(&no_download, &error_font_b64(), true)
            .unwrap();
        let ok = fonts
            .query_ttf(&no_download, &correct_font_b64(), true)
            .unwrap();
        let text = "\u{E001}杂\u{E002}";
        assert_eq!(
            FontResources::replace_font(text, Some(&err), Some(&ok), true),
            "AB"
        );
    }

    #[test]
    fn test_replace_font_blank_kept() {
        let fonts = FontResources::default();
        // 空白字符原样保留（不参与替换/filter）
        let err = fonts
            .query_ttf(&no_download, &error_font_b64(), true)
            .unwrap();
        let ok = fonts
            .query_ttf(&no_download, &correct_font_b64(), true)
            .unwrap();
        let text = "\u{E001} \u{E002}";
        assert_eq!(
            FontResources::replace_font(text, Some(&err), Some(&ok), true),
            "A B"
        );
    }

    #[test]
    fn font_boundary_lru_eviction_does_not_revoke_live_fonts_and_releases_unheld_fonts() {
        let fonts = FontResources::default();
        let held = fonts
            .query_ttf(&no_download, &error_font_b64(), true)
            .unwrap();
        let old = Arc::downgrade(&held);
        for i in 0..5 {
            let data = format!("https://font.invalid/{i}");
            fonts
                .query_ttf(
                    &|_| {
                        Ok(base64::Engine::decode(
                            &base64::engine::general_purpose::STANDARD,
                            correct_font_b64(),
                        )
                        .unwrap())
                    },
                    &data,
                    true,
                )
                .unwrap();
        }
        assert_eq!(fonts.lru.lock().unwrap().len(), 4);
        let correct = fonts
            .query_ttf(&no_download, &correct_font_b64(), false)
            .unwrap();
        assert_eq!(
            FontResources::replace_font("\u{E001}", Some(&held), Some(&correct), false),
            "A"
        );
        drop(held);
        assert!(old.upgrade().is_none());
        let cached = Arc::downgrade(&fonts.lru.lock().unwrap()[0].1);
        drop(fonts);
        assert!(cached.upgrade().is_none());
    }

    #[test]
    fn concurrent_font_queries_share_only_complete_parsed_cache_entries() {
        let fonts = FontResources::default();
        let start = std::sync::Barrier::new(8);
        std::thread::scope(|scope| {
            let workers: Vec<_> = (0..8)
                .map(|_| {
                    scope.spawn(|| {
                        start.wait();
                        fonts
                            .query_ttf(&no_download, &error_font_b64(), true)
                            .unwrap()
                    })
                })
                .collect();
            let fonts: Vec<_> = workers.into_iter().map(|w| w.join().unwrap()).collect();
            assert!(fonts.iter().all(|font| Arc::ptr_eq(&fonts[0], font)));
        });
        assert_eq!(fonts.lru.lock().unwrap().len(), 1);
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn font_boundary_any_null_and_byte_views_are_real_fonts() {
        use crate::{JsEngine, QuickJsEngine, SandboxConfig};
        let vm = QuickJsEngine::new(SandboxConfig::default().with_allow_script_run(true)).unwrap();
        assert_eq!(vm.eval("JSON.stringify([queryTTF(null)===null,java.queryTTF({})===null,queryTTF(undefined)===null,queryBase64TTF(null)===null])").unwrap(),"[true,true,true,true]");
        let code = format!(
            "var err=java.base64DecodeToByteArray('{}');var ok=java.base64DecodeToByteArray('{}');var padded=new Uint8Array(err.length+2);padded.set(err,1);var font=queryTTF(padded.subarray(1,1+err.length));JSON.stringify([typeof font,java.replaceFont('\\uE001',font,queryTTF(new Int8Array(ok.buffer)))])",
            error_font_b64(),
            correct_font_b64()
        );
        assert_eq!(vm.eval(&code).unwrap(), r#"["object","A"]"#);
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn font_boundary_invalid_data_throws_without_panicking_or_poisoning_vm() {
        use crate::{JsEngine, QuickJsEngine, SandboxConfig};
        let vm = QuickJsEngine::new(SandboxConfig::default().with_allow_script_run(true)).unwrap();
        for expression in [
            "queryTTF('AAECAwQF')",
            "queryTTF('中文')",
            "queryTTF('')",
            "queryTTF(new Uint8Array([0,1]))",
            "replaceFont('abc',{},null)",
            "queryTTF(null,null)",
            "queryTTF(null,undefined)",
        ] {
            assert_eq!(
                vm.eval(&format!("try {{{expression};'bad'}}catch(e){{'caught'}}"))
                    .unwrap(),
                "caught",
                "{expression}"
            );
            assert_eq!(vm.eval("1+1").unwrap(), "2");
        }
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn font_boundary_local_path_needs_permission_and_cannot_escape_sandbox() {
        use crate::{JsEngine, QuickJsEngine, SandboxConfig};
        let name = format!("font_boundary_{}.ttf", uuid::Uuid::new_v4());
        let path = super::super::file_utils::default_sandbox_root().join(&name);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(
            &path,
            base64::Engine::decode(&base64::engine::general_purpose::STANDARD, error_font_b64())
                .unwrap(),
        )
        .unwrap();
        let quoted = serde_json::to_string(path.to_str().unwrap()).unwrap();
        let strict = QuickJsEngine::new(SandboxConfig::default()).unwrap();
        let actual = strict
            .eval(&format!(
                "try {{queryTTF({quoted});'bad'}}catch(e){{'denied'}}"
            ))
            .unwrap();
        assert_eq!(actual, "denied");
        let permissive = QuickJsEngine::new(SandboxConfig::permissive()).unwrap();
        assert_eq!(
            permissive
                .eval(&format!("typeof queryTTF({quoted})"))
                .unwrap(),
            "object"
        );
        let outside = std::env::temp_dir().join(&name);
        std::fs::copy(&path, &outside).unwrap();
        let outside_result = permissive.eval(&format!(
            "queryTTF({})",
            serde_json::to_string(outside.to_str().unwrap()).unwrap()
        ));
        std::fs::remove_file(outside).unwrap();
        std::fs::remove_file(path).unwrap();
        assert!(outside_result.is_err());
    }

    #[test]
    fn font_boundary_cache_false_bypasses_all_layers() {
        let fonts = FontResources::default();
        let calls = std::cell::Cell::new(0);
        let download =
            |_: &str| {
                calls.set(calls.get() + 1);
                Ok(base64::Engine::decode(
                    &base64::engine::general_purpose::STANDARD,
                    error_font_b64(),
                )
                .unwrap())
            };
        let original = fonts
            .query_ttf(&download, "https://font.invalid/a.ttf", true)
            .unwrap();
        let fresh = fonts
            .query_ttf(&download, "https://font.invalid/a.ttf", false)
            .unwrap();
        let cached = fonts
            .query_ttf(&download, "https://font.invalid/a.ttf", true)
            .unwrap();
        assert!(!Arc::ptr_eq(&original, &fresh));
        assert!(Arc::ptr_eq(&original, &cached));
        assert_eq!(calls.get(), 2, "关闭缓存不能读取旧磁盘字体");
    }
}
