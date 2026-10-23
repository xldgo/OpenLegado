//! 媒体常量与基础映射由Core统一拥有；保留Fetcher公开名称。

pub use legado_core::book_media::{
    AUDIO, IMAGE, TEXT, VIDEO, WEB_FILE, source_book_type as book_type_of_source,
};
