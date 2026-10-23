//! 只读正文匹配句柄；生命周期由一次查询拥有。— Codex + Bridge
use crate::ffi::BridgeError;

#[flutter_rust_bridge::frb(opaque)]
pub struct ContentSearchMatcher {
    matcher: legado_core::content_search::ContentSearchMatcher,
}
pub struct ContentSearchHitDto {
    pub source_start: usize,
    pub source_end: usize,
    pub snippet: String,
    pub highlight_start: usize,
    pub highlight_end: usize,
}
pub fn content_search_begin(query: String, use_regex: bool) -> Option<ContentSearchMatcher> {
    legado_core::content_search::ContentSearchMatcher::new(&query, use_regex)
        .map(|matcher| ContentSearchMatcher { matcher })
}
impl ContentSearchMatcher {
    pub fn search(&self, content: String) -> Result<Vec<ContentSearchHitDto>, BridgeError> {
        self.matcher
            .search(&content)
            .map(|hits| {
                hits.into_iter()
                    .map(|h| ContentSearchHitDto {
                        source_start: h.source_start,
                        source_end: h.source_end,
                        snippet: h.snippet,
                        highlight_start: h.highlight_start,
                        highlight_end: h.highlight_end,
                    })
                    .collect()
            })
            .map_err(Into::into)
    }
}
