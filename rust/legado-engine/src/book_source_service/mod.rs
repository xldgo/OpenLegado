//! 书源管理与提交后的限速发布，不依赖宿主全局或传输DTO。
use legado_core::{LegadoError, LegadoResult, models::BookSource};
use legado_db::{BookSourceRepository, Database, repository::Repository};
use legado_fetcher::rate_limit::RateLimiterRegistry;
use serde_json::Value;

/// 成功写入对应的限速变更；不持连接或根引擎。
#[must_use = "成功写入后须在原宿主提交时机发布限速变更"]
pub struct SourceWrite<T> {
    value: T,
    rates: Vec<(String, String)>,
}
impl<T> SourceWrite<T> {
    /// 仅在最终事务提交后调用；若宿主自建外层事务，不可提前发布。
    pub fn publish(self, registry: &RateLimiterRegistry) -> T {
        for (url, rate) in self.rates {
            registry.refresh(&url, &rate);
        }
        self.value
    }
}

/// 宿主编辑入口暴露的字段；完整书源仍使用BookSource。
pub struct SourceEditFields {
    pub book_source_url: String,
    pub book_source_name: String,
    pub book_source_group: Option<String>,
    pub book_source_type: Option<i32>,
    pub enabled: Option<bool>,
    pub search_url: Option<String>,
}

/// Room入口保留解析后的实体，写入与限速变更共用同一输入。
///
/// [SOURCE-PARSE-UNIFY-20261022] 限速信息不再从原始 `Value` 独立提取，而是
/// 与解析同一份归一化实体（`parse_source_array`）生成，避免「入库用一套解释、
/// 发布限速用另一套解释」的分叉。事务成功提交后才由 `publish` 发布。
pub struct RoomSourceImport {
    sources: Vec<BookSource>,
    rates: Vec<(String, String)>,
}
impl RoomSourceImport {
    pub fn new(sources: &[&Value]) -> LegadoResult<Self> {
        let document = serde_json::to_string(sources)
            .map_err(|e| LegadoError::Internal(format!("序列化书源失败: {e}")))?;
        // 与导入同一实现：先归一化，再由同一实体产出限速键值。
        let parsed = legado_core::models::book_source::parse_source_array(&document)?;
        Self::from_entities(&parsed)
    }

    /// 直接以已解析实体构造：调用方已完成归一化时复用，避免重复解析。
    ///
    /// [SOURCE-PARSE-UNIFY-20261022] 限速键值与入库实体必须同源，禁止再
    /// 从原始 JSON 独立提取 `bookSourceUrl` / `concurrentRate`。
    pub fn from_entities(sources: &[BookSource]) -> LegadoResult<Self> {
        // 实体不能经JSON往返：None字段被省略后会重新落到缺省值。
        let rates = sources.iter().map(source_rate).collect();
        Ok(Self {
            sources: sources.to_vec(),
            rates,
        })
    }
}

pub struct BookSourceService<'a> {
    db: &'a Database,
}
impl<'a> BookSourceService<'a> {
    pub fn new(db: &'a Database) -> Self {
        Self { db }
    }
    fn repository(&self) -> BookSourceRepository<'_> {
        BookSourceRepository::new(self.db.connection())
    }
    pub fn list_sources(&self) -> LegadoResult<Vec<BookSource>> {
        self.repository().find_all()
    }
    pub fn list_enabled_sources(&self) -> LegadoResult<Vec<BookSource>> {
        self.repository().find_enabled()
    }
    pub fn add_source(&self, source: BookSource) -> LegadoResult<SourceWrite<BookSource>> {
        self.repository().insert(&source)?;
        let rates = vec![source_rate(&source)];
        Ok(SourceWrite {
            value: source,
            rates,
        })
    }
    pub fn update_source(&self, source: &BookSource) -> LegadoResult<SourceWrite<()>> {
        self.repository().update(source)?;
        Ok(SourceWrite {
            value: (),
            rates: vec![source_rate(source)],
        })
    }
    /// 沿用删除仅清数据库的语义，不额外删除限速窗口。
    pub fn delete_source(&self, url: &str) -> LegadoResult<()> {
        self.repository().delete(url)
    }
    pub fn set_source_enabled(&self, url: &str, enabled: bool) -> LegadoResult<()> {
        let repo = self.repository();
        let mut source = repo
            .find_by_url(url)?
            .ok_or_else(|| LegadoError::Database("书源不存在".into()))?;
        source.enabled = enabled;
        repo.update(&source)
    }
    pub fn set_source_variable(&self, url: &str, variable: &str) -> LegadoResult<()> {
        if !self.repository().update_variable(url, variable)? {
            return Err(LegadoError::Internal(format!("书源不存在: {url}")));
        }
        Ok(())
    }
    /// 对象规则和variable保留在完整实体中，不经Room列映射。
    pub fn import_sources(&self, sources: &[BookSource]) -> LegadoResult<SourceWrite<i32>> {
        self.repository().insert_batch(sources)?;
        Ok(SourceWrite {
            value: sources.len() as i32,
            rates: sources.iter().map(source_rate).collect(),
        })
    }
    /// 保留Room文档的原字段、事务与错误语义，返回后由原宿主发布限速。
    pub fn import_room_sources(
        &self,
        import: RoomSourceImport,
    ) -> LegadoResult<SourceWrite<usize>> {
        self.repository().insert_batch(&import.sources)?;
        Ok(SourceWrite {
            value: import.sources.len(),
            rates: import.rates,
        })
    }
    pub fn create_from_fields(
        &self,
        fields: SourceEditFields,
        rate: Option<String>,
    ) -> LegadoResult<SourceWrite<BookSource>> {
        self.add_source(BookSource {
            book_source_url: fields.book_source_url,
            book_source_name: fields.book_source_name,
            book_source_group: fields.book_source_group,
            book_source_type: fields.book_source_type.unwrap_or(0),
            enabled: fields.enabled.unwrap_or(true),
            search_url: fields.search_url,
            concurrent_rate: rate.filter(|r| !r.trim().is_empty()),
            ..Default::default()
        })
    }
    /// 编辑入口保留未暴露字段，以及原有按path查询、按body URL写入的语义。
    pub fn update_from_fields(
        &self,
        path: &str,
        fields: SourceEditFields,
        rate: Option<Option<String>>,
    ) -> LegadoResult<SourceWrite<BookSource>> {
        let transaction = self.db.immediate_transaction()?;
        let rate_change = rate.map(|value| value.filter(|r| !r.trim().is_empty()));
        let mut source = self.repository().find_by_url(path)?.unwrap_or_default();
        source.book_source_url = fields.book_source_url;
        source.book_source_name = fields.book_source_name;
        source.book_source_group = fields.book_source_group;
        source.book_source_type = fields.book_source_type.unwrap_or(0);
        source.enabled = fields.enabled.unwrap_or(true);
        source.search_url = fields.search_url;
        if let Some(value) = &rate_change {
            source.concurrent_rate = value.clone();
        }
        self.repository().update(&source)?;
        transaction
            .commit()
            .map_err(|error| LegadoError::Database(format!("提交书源更新失败: {error}")))?;
        let rates = if rate_change.is_some() {
            vec![source_rate(&source)]
        } else {
            Vec::new()
        };
        Ok(SourceWrite {
            value: source,
            rates,
        })
    }
}
fn source_rate(source: &BookSource) -> (String, String) {
    (
        source.book_source_url.clone(),
        source.concurrent_rate.as_deref().unwrap_or("").to_string(),
    )
}

#[cfg(test)]
mod tests;
