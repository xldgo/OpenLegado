//! 固定 Java Character 分类用于上游拉丁词界；不依赖宿主 Unicode 库版本。
mod tables {
    include!("unicode_tables.rs");
}
fn contains(cp: u32, ranges: &[(u32, u32)]) -> bool {
    let i = ranges.partition_point(|&(_, end)| end < cp);
    ranges
        .get(i)
        .is_some_and(|&(start, end)| start <= cp && cp <= end)
}
pub(crate) fn latin_word_part(text: &str) -> bool {
    let mut has_latin_letter = false;
    for ch in text.chars() {
        let cp = ch as u32;
        if contains(cp, tables::LETTERS) {
            if !contains(cp, tables::LATIN) {
                return false;
            }
            has_latin_letter = true;
        } else if !(contains(cp, tables::DIGITS)
            || contains(cp, tables::MARKS)
            || ch == '\''
            || ch == '\u{2019}')
        {
            return false;
        }
    }
    has_latin_letter
        || text
            .encode_utf16()
            .all(|ch| contains(ch as u32, tables::DIGITS) || ch == 39 || ch == 0x2019)
}
