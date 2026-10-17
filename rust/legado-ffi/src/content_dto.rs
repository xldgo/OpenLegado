//! 网络、抓取与段评的稳定传输结构；领域行为仍由原执行链负责。— Codex + Bridge
use crate::transfer_dto::{BookDto, ChapterDto};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebBookInfoDto {
    pub name: String,
    pub author: String,
    pub cover_url: Option<String>,
    pub intro: Option<String>,
    pub categories: Vec<String>,
    pub last_chapter: Option<String>,
    pub book_url: String,
    pub toc_url: String,
    pub word_count: Option<String>,
    pub kind: Option<String>,
    pub variable: Option<String>,
    pub book_type: i32,
}
impl From<legado_core::web_book::WebBookInfo> for WebBookInfoDto {
    fn from(value: legado_core::web_book::WebBookInfo) -> Self {
        Self {
            name: value.name,
            author: value.author,
            cover_url: value.cover_url,
            intro: value.intro,
            categories: value.categories,
            last_chapter: value.last_chapter,
            book_url: value.book_url,
            toc_url: value.toc_url,
            word_count: value.word_count,
            kind: value.kind,
            variable: value.variable,
            book_type: value.book_type,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebChapterDto {
    pub index: i32,
    pub title: String,
    pub url: String,
    pub is_vip: bool,
    pub is_volume: bool,
    pub variable: Option<String>,
    pub word_count: Option<String>,
}
impl From<legado_core::web_book::WebChapter> for WebChapterDto {
    fn from(value: legado_core::web_book::WebChapter) -> Self {
        Self {
            index: value.index,
            title: value.title,
            url: value.url,
            is_vip: value.is_vip,
            is_volume: value.is_volume,
            variable: value.variable,
            word_count: value.word_count,
        }
    }
}

impl From<WebChapterDto> for legado_core::web_book::WebChapter {
    fn from(value: WebChapterDto) -> Self {
        Self {
            index: value.index,
            title: value.title,
            url: value.url,
            is_vip: value.is_vip,
            is_volume: value.is_volume,
            variable: value.variable,
            word_count: value.word_count,
        }
    }
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebSearchResultDto {
    pub name: String,
    pub author: String,
    pub book_url: String,
    pub cover_url: Option<String>,
    pub intro: Option<String>,
    pub latest_chapter: Option<String>,
    pub source_url: String,
    pub kind: Option<String>,
    pub word_count: Option<String>,
    pub book_type: i32,
}
impl From<legado_core::web_book::WebSearchResult> for WebSearchResultDto {
    fn from(value: legado_core::web_book::WebSearchResult) -> Self {
        Self {
            name: value.name,
            author: value.author,
            book_url: value.book_url,
            cover_url: value.cover_url,
            intro: value.intro,
            latest_chapter: value.latest_chapter,
            source_url: value.source_url,
            kind: value.kind,
            word_count: value.word_count,
            book_type: value.book_type,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FlexChildStyleDto {
    pub layout_flex_grow: f32,
    pub layout_flex_shrink: f32,
    pub layout_align_self: String,
    pub layout_flex_basis_percent: f32,
    pub layout_wrap_before: bool,
    pub layout_justify_self: String,
}
impl From<legado_core::explore::FlexChildStyle> for FlexChildStyleDto {
    fn from(value: legado_core::explore::FlexChildStyle) -> Self {
        Self {
            layout_flex_grow: value.layout_flex_grow,
            layout_flex_shrink: value.layout_flex_shrink,
            layout_align_self: value.layout_align_self,
            layout_flex_basis_percent: value.layout_flex_basis_percent,
            layout_wrap_before: value.layout_wrap_before,
            layout_justify_self: value.layout_justify_self,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExploreCategoryDto {
    pub title: String,
    pub url: Option<String>,
    pub kind: String,
    pub action: Option<String>,
    pub chars: Option<Vec<Option<String>>>,
    pub default_value: Option<String>,
    pub view_name: Option<String>,
    pub style: Option<FlexChildStyleDto>,
}
impl From<legado_core::explore::ExploreCategory> for ExploreCategoryDto {
    fn from(value: legado_core::explore::ExploreCategory) -> Self {
        Self {
            title: value.title,
            url: value.url,
            kind: value.r#type,
            action: value.action,
            chars: value.chars,
            default_value: value.default_value,
            view_name: value.view_name,
            style: value.style.map(Into::into),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReviewDetailItemDto {
    pub id: Option<String>,
    pub avatar: Option<String>,
    pub name: Option<String>,
    pub badges: Vec<String>,
    pub content: Option<String>,
    pub image_url: Option<String>,
    pub audio_url: Option<String>,
    pub time: Option<String>,
    pub like_count: Option<i32>,
    pub reply_count: Option<i32>,
    pub replies: Vec<ReviewDetailItemDto>,
}
impl From<legado_parser::review_rule_parser::ReviewDetailItem> for ReviewDetailItemDto {
    fn from(value: legado_parser::review_rule_parser::ReviewDetailItem) -> Self {
        Self {
            id: value.id,
            avatar: value.avatar,
            name: value.name,
            badges: value.badges,
            content: value.content,
            image_url: value.image_url,
            audio_url: value.audio_url,
            time: value.time,
            like_count: value.like_count,
            reply_count: value.reply_count,
            replies: value.replies.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct HttpTextResponseDto {
    pub status: u16,
    pub body: String,
    pub url: String,
}
impl From<legado_net::LegadoResponse> for HttpTextResponseDto {
    fn from(v: legado_net::LegadoResponse) -> Self {
        Self {
            status: v.status,
            body: v.body,
            url: v.url,
        }
    }
}
#[derive(Debug, Clone)]
pub struct HttpBytesResponseDto {
    pub status: u16,
    pub bytes: Vec<u8>,
    pub url: String,
}
impl From<legado_net::LegadoRawResponse> for HttpBytesResponseDto {
    fn from(v: legado_net::LegadoRawResponse) -> Self {
        Self {
            status: v.status,
            bytes: v.body,
            url: v.url,
        }
    }
}
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ReviewSummaryDto {
    pub counts: HashMap<i32, i32>,
    pub keys: HashMap<i32, String>,
}
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct ReviewPageDto {
    pub items: Vec<ReviewDetailItemDto>,
    pub next_page_url: Option<String>,
    pub has_reply_url: bool,
}
#[derive(Debug, Clone)]
pub struct ReviewRequestDto {
    pub chapter_url: String,
    pub para_index: String,
    pub para_data: String,
    pub detail_url: String,
    pub reply_url: String,
    pub review_id: String,
    pub book: Option<BookDto>,
    pub chapter: Option<ChapterDto>,
}
#[derive(Debug, Clone)]
pub struct ExploreActionDto {
    pub raw: String,
    pub actions_json: String,
    pub refresh_explore: bool,
}
