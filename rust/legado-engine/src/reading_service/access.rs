//! 本地正文、在线正文入口与章节身份适配。
use super::*;
pub fn is_local_book(book_url: &str) -> bool {
    let lower = book_url.to_lowercase();
    lower.ends_with(".epub")
        || lower.ends_with(".txt")
        || lower.ends_with(".text")
        || lower.ends_with(".mobi")
        || lower.ends_with(".azw")
        || lower.ends_with(".azw3")
        || lower.ends_with(".pdf")
        || lower.ends_with(".cbz")
}

pub fn chapter_to_local_info(ch: &BookChapter) -> legado_book::ChapterInfo {
    legado_book::ChapterInfo {
        url: ch.url.clone(),
        title: ch.title.clone(),
        index: ch.index,
        is_volume: ch.is_volume,
        start: ch.start,
        end: ch.end,
    }
}

impl ReadingService {
    pub fn get_chapter_content(&self, book_url: &str, chapter_index: i32) -> LegadoResult<String> {
        self.get_chapter_content_inner(book_url, chapter_index, true)
    }
    pub fn get_chapter_content_raw(
        &self,
        book_url: &str,
        chapter_index: i32,
    ) -> LegadoResult<String> {
        self.get_chapter_content_inner(book_url, chapter_index, false)
    }
    pub(super) fn get_chapter_content_inner(
        &self,
        book_url: &str,
        chapter_index: i32,
        apply_replace_rules: bool,
    ) -> LegadoResult<String> {
        // 查询章节信息
        let chapter = self
            .with_database(|db| {
                let repo = BookChapterRepository::new(db.connection());
                repo.find_by_book_url_and_index(book_url, chapter_index)
            })?
            .ok_or_else(|| LegadoError::Database(format!("章节 {chapter_index} 不存在")))?;

        // 判断是否为本地书籍
        if is_local_book(book_url) {
            // 使用 legado-book 解析本地文件
            // [C1] 还原为真实文件路径（相对标识 → 当前 Documents；绝对原样）
            let real_path = (self.resources.resolve_path)(book_url);
            let content = legado_book::LocalBook::get_chapter_content(
                &real_path,
                &chapter_to_local_info(&chapter),
            )?;
            // 读取时净化：DB/文件保留原始正文，返回前应用内容净化
            Ok(self.apply_content_processing_inner(
                book_url,
                &content,
                &chapter.title,
                apply_replace_rules,
                Some(chapter_index),
                apply_replace_rules,
            ))
        } else {
            // 在线书籍：返回章节 URL 信息，由上层配合书源规则获取正文
            // 简化实现：返回章节 URL 供 Dart 侧进一步处理（标题做显示层繁简转换）
            Ok(serde_json::to_string(&serde_json::json!({
                "chapter_url": chapter.url,
                "base_url": chapter.base_url,
                "title": convert_title_by_type(&chapter.title, self.get_chinese_convert_type()),
                "need_fetch": true,
            }))?)
        }
    }
    pub fn fetch_chapter_content(
        &self,
        book_url: &str,
        chapter_url: &str,
        source_url: &str,
    ) -> LegadoResult<String> {
        // 取得真实章节序号与标题（供去重复标题与缓存使用）
        // [B-12] 第 4 项 known_chapter：未知章节 URL 时不得回退 (0, "") 并写
        // index=0 缓存行（污染缓存且目录云图标错位）
        let (chapter_index, chapter_title, chapter_variable, known_chapter) =
            self.get_chapter_index_title_variable(book_url, chapter_url)?;
        self.fetch_chapter_content_inner(ChapterRequest {
            book_url,
            chapter_url,
            source_url,
            chapter_index,
            chapter_title: &chapter_title,
            chapter_variable: chapter_variable.as_deref(),
            known_chapter,
        })
    }
    pub(super) fn fetch_chapter_content_inner(
        &self,
        request: ChapterRequest<'_>,
    ) -> LegadoResult<String> {
        let ChapterRequest {
            book_url,
            chapter_url,
            source_url,
            chapter_index,
            chapter_title,
            chapter_variable,
            known_chapter,
        } = request;

        let access = self.chapter_content()?;
        let task = self
            .resources
            .tasks
            .begin()
            .map_err(|e| LegadoError::Ffi(e.to_string()))?;
        let raw = access.read(
            ChapterRequest {
                book_url,
                chapter_url,
                source_url,
                chapter_index,
                chapter_title,
                chapter_variable,
                known_chapter,
            },
            Some(&task),
        )?;
        Ok(
            self.apply_content_processing_chapter(
                book_url,
                &raw.content,
                &raw.title,
                chapter_index,
            ),
        )
    }
    pub fn get_chapter_content_full(
        &self,
        book_url: &str,
        chapter_index: i32,
    ) -> LegadoResult<String> {
        // 1. 查询章节信息
        let chapter = self
            .with_database(|db| {
                let repo = BookChapterRepository::new(db.connection());
                repo.find_by_book_url_and_index(book_url, chapter_index)
            })?
            .ok_or_else(|| LegadoError::Database(format!("章节 {chapter_index} 不存在")))?;

        // 2. 本地书籍：解析文件 + 净化
        if is_local_book(book_url) {
            let content = legado_book::LocalBook::get_chapter_content(
                book_url,
                &chapter_to_local_info(&chapter),
            )?;
            return Ok(self.apply_content_processing_chapter(
                book_url,
                &content,
                &chapter.title,
                chapter.index,
            ));
        }

        // 3. 在线书籍：查找书籍获取书源 URL（book.origin）
        let book = self
            .with_database(|db| {
                let repo = BookRepository::new(db.connection());
                repo.find_by_url(book_url)
            })?
            .ok_or_else(|| LegadoError::Database(format!("书籍 {book_url} 不存在")))?;

        if book.origin.is_empty() {
            return Err(LegadoError::Database(format!(
                "书籍 {book_url} 未配置书源（origin 为空）"
            )));
        }
        let source_url = book.origin;

        // 直接调用 inner，复用已持有的章节信息，避免冗余的 get_chapter_index_and_title 查询
        // （章节经 find_by_book_url_and_index 定位，必然已知 → known_chapter=true）
        self.fetch_chapter_content_inner(ChapterRequest {
            book_url,
            chapter_url: &chapter.url,
            source_url: &source_url,
            chapter_index: chapter.index,
            chapter_title: &chapter.title,
            chapter_variable: chapter.variable.as_deref(),
            known_chapter: true,
        })
    }
}
