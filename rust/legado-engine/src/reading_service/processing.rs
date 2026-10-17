//! 正文处理配置与纯文本规则。
use super::*;
const SAME_TITLE_REMOVED_KEY_PREFIX: &str = "sameTitleRemoved:";
use legado_core::content_processor::{ContentProcessor, ProcessorConfig, ReplaceRuleEntry};
pub fn chinese_convert_direction(convert_type: i32) -> Option<String> {
    match convert_type {
        1 => Some("t2s".to_string()),
        2 => Some("s2t".to_string()),
        _ => None,
    }
}

pub fn same_title_removed_key(book_url: &str, chapter_index: i32) -> String {
    format!("{SAME_TITLE_REMOVED_KEY_PREFIX}{book_url}:{chapter_index}")
}

pub fn can_remove_same_title(chapter_title: &str, raw_content: &str) -> bool {
    if chapter_title.is_empty() || raw_content.is_empty() {
        return false;
    }
    raw_content.trim_start().starts_with(chapter_title)
}

pub fn convert_title_by_type(title: &str, convert_type: i32) -> String {
    match convert_type {
        1 => legado_core::chinese_convert::traditional_to_simplified(title),
        2 => legado_core::chinese_convert::simplified_to_traditional(title),
        _ => title.to_string(),
    }
}

pub fn word_count_format(words: usize) -> String {
    if words == 0 {
        return String::new();
    }
    if words <= 10000 {
        return format!("{words}字");
    }
    let v = f64::from(words as f32) / 10000.0;
    let bits = v.to_bits();
    let exp_field = ((bits >> 52) & 0x7FF) as i32;
    let mantissa = ((bits & 0x000F_FFFF_FFFF_FFFF) | (1u64 << 52)) as u128;
    // v = mantissa × 2^(exp_field-1075)；求 t = round_HALF_EVEN(v×10)
    //（v×10 的精确值即 mantissa×10 × 2^e，e≥0 为纯移位无舍入）
    let e = exp_field - 1075;
    let n = mantissa * 10;
    let t = if e >= 0 {
        n << e.min(72) as u32 // e>72 对现实字数不可达
    } else {
        let d_exp = (-e) as u32;
        let q = n >> d_exp;
        let r = n & ((1u128 << d_exp) - 1);
        let half = 1u128 << d_exp;
        let twice_r = 2 * r;
        if twice_r > half {
            q + 1
        } else if twice_r < half {
            q
        } else {
            // tie（恰为 .5）→ HALF_EVEN 取偶数侧
            if q.is_multiple_of(2) { q } else { q + 1 }
        }
    };
    let (int_part, frac_part) = (t / 10, t % 10);
    if frac_part == 0 {
        format!("{int_part}万字")
    } else {
        format!("{int_part}.{frac_part}万字")
    }
}

pub fn process_content_with_rules_inner(
    raw_content: &str,
    chapter_title: &str,
    rules: &[ReplaceRule],
    book_name: &str,
    apply_replace_rules: bool,
    chinese_convert: Option<String>,
    remove_duplicate_title: bool,
) -> String {
    // 2. 按 scope 过滤（与 Android 语义一致，并修复空 book_name 守卫与精确匹配）：
    //    - None → 全局生效
    //    - Some(scope)：scope 为空或 "global" → 全局；
    //      否则仅当 book_name 非空，且 scope 按 [,;，；] 拆分后存在 trim()==book_name 的精确项才生效。
    let entries: Vec<ReplaceRuleEntry> = rules
        .iter()
        .filter(|rule| match &rule.scope {
            None => true,
            Some(scope) => {
                if scope.is_empty() || scope == "global" {
                    true
                } else if book_name.is_empty() {
                    // book_name 为空时，带具体 scope 的规则不生效（避免 contains("") 恒真）
                    false
                } else {
                    scope
                        .split([',', ';', '，', '；'])
                        .any(|item| item.trim() == book_name)
                }
            }
        })
        .map(ReplaceRuleEntry::from_replace_rule)
        .collect();

    // 3. 构造处理器：启用「去重复标题 + 替换规则 + 简繁转换」，与 Android 净化行为对等
    //    apply_replace_rules 由调用方控制（阅读器/导出=true，内容搜索=false）
    //    chinese_convert 来自持久化配置 chineseConverterType（0/1/2 → None/t2s/s2t）
    //    remove_duplicate_title 来自章级开关（Task #51，全局默认 true）
    let config = ProcessorConfig {
        remove_duplicate_title,
        re_segment: false,
        chinese_convert,
        apply_replace_rules,
        indent_spaces: 0,
        trim_empty_lines: false,
    };
    let processor = ContentProcessor::new(config);
    processor.process(raw_content, chapter_title, &entries)
}

impl ReadingService {
    pub fn get_chinese_convert_type(&self) -> i32 {
        self.with_database(|db| {
            Ok(CacheRepository::new(db.connection())
                .get("config:chineseConverterType")?
                .unwrap_or_default())
        })
        .ok()
        .and_then(|v| v.parse::<i32>().ok())
        .filter(|t| (0..=2).contains(t))
        .unwrap_or(0)
    }
    pub fn set_chinese_convert_type(&self, convert_type: i32) {
        let normalized = if (0..=2).contains(&convert_type) {
            convert_type
        } else {
            0
        };
        let _ = self.with_database(|db| {
            CacheRepository::new(db.connection()).put(
                "config:chineseConverterType",
                &normalized.to_string(),
                0,
            )
        });
    }
    pub(super) fn current_chinese_convert_direction(&self) -> Option<String> {
        chinese_convert_direction(self.get_chinese_convert_type())
    }
    pub(super) fn is_same_title_removed(&self, book_url: &str, chapter_index: i32) -> bool {
        // DB 读取异常不再静默吞错：warn 后回退全局默认 true（返回值行为不变）
        let value = match self.with_database(|db| {
            let repo = CacheRepository::new(db.connection());
            repo.get(&same_title_removed_key(book_url, chapter_index))
        }) {
            Ok(value) => value,
            Err(e) => {
                log::warn!("读取章级删除重复标题开关失败，回退全局默认 true: {e}");
                None
            }
        };
        !matches!(value.as_deref(), Some("1"))
    }
    pub fn get_same_title_removed(&self, book_url: &str, chapter_index: i32) -> bool {
        self.is_same_title_removed(book_url, chapter_index)
    }
    pub fn toggle_same_title_removed(
        &self,
        book_url: &str,
        chapter_index: i32,
        enable: bool,
    ) -> LegadoResult<()> {
        // 1. 书籍存在性校验（不存在 → Internal 错误）
        let book_exists = self.with_database(|db| {
            Ok(BookRepository::new(db.connection())
                .find_by_url(book_url)?
                .is_some())
        })?;
        if !book_exists {
            return Err(LegadoError::Internal(format!("书籍不存在: {book_url}")));
        }

        // 2. 章节存在性校验（不存在 → Db 错误）
        let chapter_exists = self.with_database(|db| {
            Ok(BookChapterRepository::new(db.connection())
                .find_by_book_url_and_index(book_url, chapter_index)?
                .is_some())
        })?;
        if !chapter_exists {
            return Err(LegadoError::Database(format!(
                "章节 {chapter_index} 不存在: {book_url}"
            )));
        }

        // 3. 持久化：opt-out 写 "1"；恢复默认则删除记录（保持存储精简）
        self.with_database(|db| {
            let repo = CacheRepository::new(db.connection());
            let key = same_title_removed_key(book_url, chapter_index);
            if enable {
                repo.delete(&key)?;
            } else {
                repo.put(&key, "1", 0)?; // ttl=0 永不过期
            }
            Ok(())
        })
    }
    pub(super) fn apply_title_convert(&self, chapters: &mut [BookChapter]) {
        let convert_type = self.get_chinese_convert_type();
        if convert_type == 0 {
            return;
        }
        for ch in chapters.iter_mut() {
            ch.title = convert_title_by_type(&ch.title, convert_type);
        }
    }
    pub fn apply_content_processing(
        &self,
        book_url: &str,
        raw_content: &str,
        chapter_title: &str,
    ) -> String {
        self.apply_content_processing_inner(book_url, raw_content, chapter_title, true, None)
    }
    pub fn apply_content_processing_chapter(
        &self,
        book_url: &str,
        raw_content: &str,
        chapter_title: &str,
        chapter_index: i32,
    ) -> String {
        self.apply_content_processing_inner(
            book_url,
            raw_content,
            chapter_title,
            true,
            Some(chapter_index),
        )
    }
    pub fn apply_content_processing_raw(
        &self,
        book_url: &str,
        raw_content: &str,
        chapter_title: &str,
        chapter_index: Option<i32>,
    ) -> String {
        self.apply_content_processing_inner(
            book_url,
            raw_content,
            chapter_title,
            false,
            chapter_index,
        )
    }
    pub(super) fn apply_content_processing_inner(
        &self,
        book_url: &str,
        raw_content: &str,
        chapter_title: &str,
        apply_replace_rules: bool,
        chapter_index: Option<i32>,
    ) -> String {
        // 1. 加载启用的替换规则 + 查询书籍名称（用于 scope 过滤）
        let loaded = self.with_database(|db| {
            let rule_repo = ReplaceRuleRepository::new(db.connection());
            let rules = rule_repo.get_enabled_rules()?;
            let book_repo = BookRepository::new(db.connection());
            let book_name = book_repo
                .find_by_url(book_url)?
                .map(|b| b.name)
                .unwrap_or_default();
            Ok((rules, book_name))
        });

        let (rules, book_name) = match loaded {
            Ok(v) => v,
            // 数据库不可用或查询失败时，退化为不净化（与无规则时行为一致）
            Err(_) => return raw_content.to_string(),
        };

        // 繁简转换仅作用于阅读器/导出正文路径（apply_replace_rules=true）；
        // 内容搜索 raw 路径保持原文，避免搜不到被转换的词
        // （对齐 Kotlin BookHelp.getContent 的 replaceEnabled=false 路径）。
        let chinese_convert = if apply_replace_rules {
            self.current_chinese_convert_direction()
        } else {
            None
        };

        // 章级「删除重复标题」开关（Task #51）：无章节上下文时维持全局默认 true；
        // 带 chapter_index 的路径（阅读器/导出，以及 apply_content_processing_raw
        // 显式传入时）均尊重章级 opt-out，对齐原版 removeSameTitleCache
        // 不受 useReplace 影响的行为
        let remove_duplicate_title = chapter_index
            .map(|idx| self.is_same_title_removed(book_url, idx))
            .unwrap_or(true);

        process_content_with_rules_inner(
            raw_content,
            chapter_title,
            &rules,
            &book_name,
            apply_replace_rules,
            chinese_convert,
            remove_duplicate_title,
        )
    }
}
