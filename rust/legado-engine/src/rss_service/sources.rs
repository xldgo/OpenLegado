//! 源管理沿用既有字段、顺序及写入错误语义。
use super::*;
impl RssService {
    pub fn list_rss_sources(&self) -> LegadoResult<Vec<RssSource>> {
        self.with_database(|db| {
            RssSourceRepository::new(db.connection())
                .find_all_skip_invalid()
                .map_err(LegadoError::Database)
        })
    }

    pub fn add_rss_source_entity(&self, source: RssSource) -> LegadoResult<RssSource> {
        self.with_database(|db| {
            let repo = RssSourceRepository::new(db.connection());
            repo.insert(&source)
                .map_err(|e| LegadoError::Database(format!("插入 RSS 源失败: {e}")))?;
            Ok(source)
        })
    }

    pub fn update_rss_source_entity(&self, source: RssSource) -> LegadoResult<RssSource> {
        if source.source_url.trim().is_empty() {
            return Err(LegadoError::Ffi("RssSource sourceUrl 不能为空".into()));
        }
        self.with_database(|db| {
            let repo = RssSourceRepository::new(db.connection());
            let updated = repo
                .update_fields(&source)
                .map_err(|e| LegadoError::Database(format!("原子更新 RSS 源失败: {e}")))?;
            if !updated {
                return Err(LegadoError::Database(format!(
                    "RSS 源不存在: {}",
                    source.source_url
                )));
            }
            Ok(source)
        })
    }

    pub fn delete_default_rss_sources(&self) -> LegadoResult<i32> {
        self.with_database(|db| {
            let conn = db.connection();
            let n = conn
                .execute("DELETE FROM rssSources WHERE sourceGroup = 'legado'", [])
                .map_err(|e| LegadoError::Database(format!("删除默认 RSS 源失败: {e}")))?;
            Ok(n as i32)
        })
    }

    pub fn delete_rss_source(&self, source_url: &str) -> LegadoResult<()> {
        self.with_database(|db| {
            let conn = db.connection();
            conn.execute(
                "DELETE FROM rssSources WHERE sourceUrl = ?1",
                rusqlite::params![source_url],
            )
            .map_err(|e| LegadoError::Database(format!("删除 RSS 源失败: {e}")))?;
            Ok(())
        })
    }

    pub fn import_rss_sources(&self, sources: Vec<RssSource>) -> LegadoResult<i32> {
        self.with_database(|db| {
            let repo = RssSourceRepository::new(db.connection());
            let mut imported = 0i32;
            for source in &sources {
                repo.insert(source)
                    .map_err(|e| LegadoError::Database(format!("导入 RSS 源失败: {e}")))?;
                imported += 1;
            }
            Ok(imported)
        })
    }
}
