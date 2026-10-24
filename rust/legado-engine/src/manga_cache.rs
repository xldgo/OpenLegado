//! 手动漫画离线缓存：正文行与图片文件分别保留，图片齐全才算章节完成。
use std::{collections::HashSet, sync::Arc};

use legado_book::export::extract_image_sources;
use legado_core::{
    LegadoError, LegadoResult,
    models::{BookChapter, book::book_type},
};
use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository, CacheBookRepository};

use crate::{
    NetworkContext, StorageContext, TaskHandle,
    image_cache_service::ImageCacheService,
    image_service::{ImageService, looks_like_image_bytes},
};

/// 是否需要漫画图片完整性判定；本地书、音视频保持原路径。— Codex + Rust
pub fn is_manga(storage: &StorageContext, book_url: &str) -> LegadoResult<bool> {
    storage.with_database(|db| {
        let Some(book) = BookRepository::new(db.connection()).find_by_url(book_url)? else {
            return Ok(false);
        };
        if book.origin == book_type::LOCAL_TAG
            || matches!(book.book_type, book_type::AUDIO | book_type::VIDEO)
        {
            return Ok(false);
        }
        Ok(book.book_type == book_type::IMAGE
            || BookSourceRepository::new(db.connection())
                .find_by_url(&book.origin)?
                .is_some_and(|source| source.book_source_type == book_type::IMAGE))
    })
}

/// 复用正文格式化/图片提取器，不另建HTML解析器；章节封面与正文顺序对应阅读器。
fn image_urls(content: &str, chapter: &BookChapter) -> Vec<String> {
    let normalized = legado_core::html_formatter::format_keep_img(content, &chapter.url);
    let mut urls = extract_image_sources(&normalized);
    if urls.is_empty() {
        urls = content
            .lines()
            .map(str::trim)
            .filter(|line| {
                let base = line.split(",{").next().unwrap_or(line).to_ascii_lowercase();
                base.starts_with("http")
                    && !["m3u8", "ffzy-plays", "ffzy-play"]
                        .iter()
                        .any(|x| base.contains(x))
                    && ([".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"]
                        .iter()
                        .any(|ext| base.ends_with(ext))
                        || ["/image", "/img", "/pic"]
                            .iter()
                            .any(|path| base.contains(path)))
            })
            .map(str::to_owned)
            .collect();
    }
    if let Some(cover) = chapter.img_url.as_ref().filter(|url| !url.is_empty()) {
        urls.insert(0, cover.clone());
    }
    urls
}

/// 不以正文缓存替代图片完整性，也不在查询时下载或修复。
pub fn images_complete(
    cache: &ImageCacheService,
    book_url: &str,
    content: &str,
    chapter: &BookChapter,
) -> bool {
    if chapter.is_volume {
        return true;
    }
    let images = image_urls(content, chapter);
    !images.is_empty()
        && images
            .iter()
            .all(|url| cache.has_image_cache(book_url, url))
}

pub struct PrefetchWindow<'a> {
    pub book_url: &'a str,
    pub current_chapter: i32,
    pub next_count: i32,
    pub previous_count: i32,
}

/// 自动窗口只持有调用任务；手动队列、断点和任务ID完全不在此路径。
pub fn prefetch(
    storage: &StorageContext,
    execute: &crate::ChapterDownload,
    window: PrefetchWindow<'_>,
    task: &TaskHandle,
    mut completed: impl FnMut(i32) -> bool,
) -> LegadoResult<()> {
    let PrefetchWindow {
        book_url,
        current_chapter,
        next_count,
        previous_count,
    } = window;
    if !is_manga(storage, book_url)? || task.is_cancelled() {
        return Ok(());
    }
    let chapters = storage.with_database(|db| {
        BookChapterRepository::new(db.connection()).find_by_book_url(book_url)
    })?;
    let candidates = chapters.iter().filter(|chapter| {
        let offset = i64::from(chapter.index) - i64::from(current_chapter);
        !chapter.is_volume
            && ((offset > 0 && offset <= i64::from(next_count))
                || (offset < 0 && -offset <= i64::from(previous_count)))
    });
    // 使用真实目录索引，不能把稀疏目录条数当作最后一章索引。
    let mut indices: Vec<i32> = candidates.map(|chapter| chapter.index).collect();
    indices.sort_by_key(|&index| {
        if index > current_chapter {
            (0, i64::from(index))
        } else {
            (1, -i64::from(index))
        }
    });
    for index in indices {
        if task.is_cancelled() {
            break;
        }
        match execute(book_url, index, task) {
            Ok(()) => {
                if task.with_active(|| completed(index)) != Some(true) {
                    break;
                }
            }
            Err(error) if !task.is_cancelled() => {
                log::debug!("漫画自动缓存章节{index}失败: {error}")
            }
            Err(_) => break,
        }
    }
    Ok(())
}

pub struct MangaCache {
    storage: StorageContext,
    network: Arc<NetworkContext>,
    images: ImageService,
    runtime: tokio::runtime::Handle,
}

impl MangaCache {
    pub fn new(
        storage: StorageContext,
        network: Arc<NetworkContext>,
        js: Arc<legado_js::JsResources>,
        runtime: tokio::runtime::Handle,
    ) -> Self {
        Self {
            storage,
            network,
            images: ImageService::new(js),
            runtime,
        }
    }

    pub fn download(
        &self,
        book_url: &str,
        index: i32,
        task: &TaskHandle,
        cache: &ImageCacheService,
    ) -> LegadoResult<()> {
        if !is_manga(&self.storage, book_url)? {
            return Ok(());
        }
        let data = self.storage.with_database(|db| {
            let conn = db.connection();
            let chapter = BookChapterRepository::new(conn)
                .find_by_book_url_and_index(book_url, index)?
                .ok_or_else(|| LegadoError::Database(format!("章节 {index} 不存在")))?;
            if chapter.is_volume {
                return Ok(None);
            }
            let book = BookRepository::new(conn)
                .find_by_url(book_url)?
                .ok_or_else(|| LegadoError::Database("书籍不存在".into()))?;
            let source = BookSourceRepository::new(conn)
                .find_by_url(&book.origin)?
                .ok_or_else(|| LegadoError::Database("漫画书源不存在".into()))?;
            let content = CacheBookRepository::new(conn)
                .get_by_book_and_chapter_url(book_url, &chapter.url)?
                .ok_or_else(|| LegadoError::Database("漫画正文未缓存，无法完成离线下载".into()))?;
            Ok(Some((source, content.content, chapter)))
        })?;
        let Some((source, content, chapter)) = data else {
            return Ok(());
        };
        let urls = image_urls(&content, &chapter);
        if urls.is_empty() {
            return Err(LegadoError::Parser("漫画章节没有图片".into()));
        }
        let mut visited = HashSet::new();
        for url in urls {
            if task.is_cancelled() {
                return Err(LegadoError::Ffi("漫画下载已取消".into()));
            }
            if !visited.insert(url.clone()) {
                continue;
            }
            if cache.has_image_cache(book_url, &url) {
                continue;
            }
            let bytes = self.images.fetch_for_task(
                &url,
                &source,
                &self.network,
                &self.runtime,
                Some(task),
            )?;
            if !looks_like_image_bytes(&bytes) {
                return Err(LegadoError::Parser(format!(
                    "漫画图片响应不是有效图片: {url}"
                )));
            }
            let saved = task
                .with_active(|| cache.save_image_cache(book_url, &url, &bytes))
                .ok_or_else(|| LegadoError::Ffi("漫画下载已取消".into()))?;
            if !saved {
                return Err(LegadoError::Io(std::io::Error::other(format!(
                    "漫画图片写入失败: {url}"
                ))));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests;
