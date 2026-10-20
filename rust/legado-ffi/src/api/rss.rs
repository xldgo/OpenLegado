//! RSS宿主适配：存储/网络装配及真实文档解析，业务委托Engine。
use legado_core::models::RssSource;
use legado_core::{LegadoError, LegadoResult};
pub use legado_engine::rss_service::RssArticle;
use legado_engine::rss_service::RssService;
/// 共用存储装配，不让收藏/已读入口隐式启动网络或运行时。
pub(super) fn host_service() -> RssService {
    RssService::new(
        crate::engine_holder::current()
            .ok()
            .map(|engine| engine.storage().clone()),
    )
}
pub fn list_rss_sources() -> LegadoResult<Vec<RssSource>> {
    host_service().list_rss_sources()
}

pub fn add_rss_source_entity(source: RssSource) -> LegadoResult<RssSource> {
    host_service().add_rss_source_entity(source)
}

pub fn update_rss_source_entity(source: RssSource) -> LegadoResult<RssSource> {
    host_service().update_rss_source_entity(source)
}

pub fn delete_default_rss_sources() -> LegadoResult<i32> {
    host_service().delete_default_rss_sources()
}

pub fn delete_rss_source(source_url: &str) -> LegadoResult<()> {
    host_service().delete_rss_source(source_url)
}

pub fn clear_rss_articles(source_url: &str) -> LegadoResult<()> {
    host_service().clear_rss_articles(source_url)
}

pub fn add_rss_source(source_json: &str) -> LegadoResult<RssSource> {
    let source: RssSource = serde_json::from_str(source_json)
        .map_err(|e| LegadoError::Ffi(format!("RssSource JSON 解析失败: {e}")))?;
    add_rss_source_entity(source)
}

pub fn update_rss_source(source_json: &str) -> LegadoResult<RssSource> {
    let source: RssSource = serde_json::from_str(source_json)
        .map_err(|e| LegadoError::Ffi(format!("RssSource JSON 解析失败: {e}")))?;
    update_rss_source_entity(source)
}

pub fn export_rss_sources() -> LegadoResult<String> {
    let sources = list_rss_sources()?;
    serde_json::to_string(&sources).map_err(|e| LegadoError::Ffi(format!("RSS 源序列化失败: {e}")))
}

pub fn import_rss_sources(json_array: &str) -> LegadoResult<i32> {
    let sources: Vec<RssSource> = serde_json::from_str(json_array)
        .map_err(|e| LegadoError::Ffi(format!("RSS 源 JSON 数组解析失败: {e}")))?;
    host_service().import_rss_sources(sources)
}

pub fn fetch_rss_articles(source_url: &str) -> LegadoResult<Vec<RssArticle>> {
    let (service, network) = {
        let engine = crate::engine_holder::current().ok();
        (
            RssService::new(engine.as_ref().map(|e| e.storage().clone())),
            engine
                .as_ref()
                .map(|e| e.network().clone())
                .unwrap_or_else(crate::engine_holder::network),
        )
    };
    service.fetch_rss_articles(source_url, &network, crate::runtime::get_runtime().handle())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_rss_source_persists_group_and_single_url() {
        let _guard = crate::db_state::ensure_test_db();
        let json = r#"{
            "sourceUrl":"https://www.yuque.com/legado",
            "sourceName":"使用说明",
            "sourceGroup":"legado",
            "sourceIcon":"https://example.com/icon.png",
            "enabled":true,
            "singleUrl":true,
            "customOrder":2
        }"#;
        let added = add_rss_source(json).expect("add");
        assert_eq!(added.source_group.as_deref(), Some("legado"));
        assert!(added.single_url);

        let listed = list_rss_sources().expect("list");
        let found = listed
            .iter()
            .find(|s| s.source_url == "https://www.yuque.com/legado")
            .expect("found");
        assert_eq!(found.source_group.as_deref(), Some("legado"));
        assert!(found.single_url);

        let n = import_rss_sources(
            r#"[{"sourceUrl":"https://pan.miaogongzi.net","sourceName":"Meow云","sourceGroup":"legado","singleUrl":true,"enabled":true}]"#,
        )
        .expect("import");
        assert_eq!(n, 1);
        let _ = delete_rss_source("https://www.yuque.com/legado");
        let _ = delete_rss_source("https://pan.miaogongzi.net");
    }
}
