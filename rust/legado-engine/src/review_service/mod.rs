//! 段评应用服务：原规则与JS两路编排，使用显式实例能力。
mod js;
mod model;
mod rules;

use crate::NetworkContext;
use legado_core::{LegadoError, LegadoResult, models::BookSource};
use legado_parser::AnalyzeRule;
pub use model::{ReviewPage, ReviewRequest, ReviewSummary};
use std::sync::Arc;

pub struct ReviewResources {
    pub network: Arc<NetworkContext>,
    pub js: Arc<legado_js::JsResources>,
    pub runtime: tokio::runtime::Handle,
}
pub struct ReviewService {
    resources: ReviewResources,
}
impl ReviewService {
    pub fn new(resources: ReviewResources) -> Self {
        Self { resources }
    }
    fn construct_analyzer(
        &self,
        content: String,
        base_url: String,
        source_tag: &str,
    ) -> AnalyzeRule {
        legado_fetcher::js_adapter::construct_analyzer_with_js_lib(
            &self.resources.js.for_source("source", source_tag, ""),
            content,
            base_url,
            source_tag,
            None,
        )
    }
    fn build_js_orchestrator(
        &self,
        source: &BookSource,
    ) -> LegadoResult<Option<legado_js::js_source::js_source_book::JsSourceBookOrchestrator>> {
        legado_fetcher::web_book::build_js_orchestrator(
            &self
                .resources
                .js
                .for_source("source", &source.book_source_url, ""),
            source,
        )
    }
}

#[cfg(test)]
mod tests;
