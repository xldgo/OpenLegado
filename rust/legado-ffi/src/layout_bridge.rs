//! 布局 FFI 只管理批量协议与隔离会话，断行和分页完全交给 legado-layout。
use crate::ffi::BridgeError;
use legado_layout::{
    model::{Block, Config, Page},
    paginator::{validate_block, PaginationSession},
};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc, Mutex, OnceLock,
    },
    time::Instant,
};

const MAX_SESSIONS: usize = 8;
const MAX_JSON_BYTES: usize = 16 * 1024 * 1024;
const MAX_BATCH_BLOCKS: usize = 32;
const MAX_BATCH_ITEMS: usize = 250_000;
struct Session {
    core: Mutex<PaginationSession>,
    cancelled: Arc<AtomicBool>,
}
static SESSIONS: OnceLock<Mutex<HashMap<String, Arc<Session>>>> = OnceLock::new();
static NEXT_ID: AtomicU64 = AtomicU64::new(1);
fn sessions() -> &'static Mutex<HashMap<String, Arc<Session>>> {
    SESSIONS.get_or_init(|| Mutex::new(HashMap::new()))
}
fn error(message: impl ToString) -> BridgeError {
    BridgeError {
        message: message.to_string(),
    }
}
fn lock<T>(mutex: &Mutex<T>) -> Result<std::sync::MutexGuard<'_, T>, BridgeError> {
    mutex.lock().map_err(|_| error("阅读布局会话锁损坏"))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Begin {
    schema_version: u32,
    config: Config,
}
#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Push {
    schema_version: u32,
    blocks: Vec<Block>,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Reply<'a> {
    schema_version: u32,
    session_id: &'a str,
    #[serde(flatten)]
    layout: legado_layout::wire::WirePages,
    rust_micros: u64,
}
fn parse<T: serde::de::DeserializeOwned>(input: &str) -> Result<T, BridgeError> {
    if input.len() > MAX_JSON_BYTES {
        return Err(error("阅读布局 JSON 超过 16 MiB"));
    }
    serde_json::from_str(input).map_err(error)
}
fn version(schema: u32) -> Result<(), BridgeError> {
    if schema == legado_layout::SCHEMA_VERSION {
        Ok(())
    } else {
        Err(error("不支持的阅读布局 schemaVersion"))
    }
}
fn reply(id: &str, pages: Vec<Page>, start: Instant) -> Result<String, BridgeError> {
    let elapsed = start.elapsed().as_micros().min(u64::MAX as u128) as u64;
    serde_json::to_string(&Reply {
        schema_version: legado_layout::SCHEMA_VERSION,
        session_id: id,
        layout: legado_layout::wire::pack_pages(pages),
        rust_micros: elapsed,
    })
    .map_err(error)
}
pub(crate) fn begin(input: &str) -> Result<String, BridgeError> {
    let start = Instant::now();
    let request: Begin = parse(input)?;
    version(request.schema_version)?;
    let mut core = PaginationSession::new(request.config).map_err(error)?;
    let token = Arc::new(AtomicBool::new(false));
    core.set_cancellation(token.clone());
    let mut registry = lock(sessions())?;
    if registry.len() >= MAX_SESSIONS {
        return Err(error("阅读布局会话达到上限，请取消旧会话"));
    }
    let id = NEXT_ID.fetch_add(1, Ordering::Relaxed).to_string();
    registry.insert(
        id.clone(),
        Arc::new(Session {
            core: Mutex::new(core),
            cancelled: token,
        }),
    );
    drop(registry);
    reply(&id, vec![], start)
}
pub(crate) fn push(id: &str, input: &str) -> Result<String, BridgeError> {
    let start = Instant::now();
    let result = (|| {
        let request: Push = parse(input)?;
        version(request.schema_version)?;
        if request.blocks.len() > MAX_BATCH_BLOCKS {
            return Err(error("阅读布局单批内容块超过 32"));
        }
        let count: usize = request
            .blocks
            .iter()
            .map(|b| match b {
                Block::Paragraph { value } => value.clusters.len(),
                Block::InlineParagraph(p) => p.items.len(),
                _ => 1,
            })
            .sum();
        if count > MAX_BATCH_ITEMS {
            return Err(error("阅读布局单批行内项超过 250000"));
        }
        for b in &request.blocks {
            validate_block(b).map_err(error)?;
        }
        let entry = lock(sessions())?
            .get(id)
            .cloned()
            .ok_or_else(|| error("阅读布局会话不存在或已取消"))?;
        let mut core = lock(&entry.core)?;
        let mut pages = vec![];
        for b in request.blocks {
            pages.extend(core.accept(b).map_err(error)?);
        }
        if entry.cancelled.load(Ordering::Acquire) {
            return Err(error("阅读布局会话已取消"));
        }
        reply(id, pages, start)
    })();
    if result.is_err() {
        cancel(id)?;
    }
    result
}
pub(crate) fn finish(id: &str) -> Result<String, BridgeError> {
    let start = Instant::now();
    let entry = lock(sessions())?
        .get(id)
        .cloned()
        .ok_or_else(|| error("阅读布局会话不存在或已取消"))?;
    let result = (|| {
        let pages = lock(&entry.core)?.finish().map_err(error)?;
        if entry.cancelled.load(Ordering::Acquire) {
            return Err(error("阅读布局会话已取消"));
        }
        reply(id, pages, start)
    })();
    cancel(id)?;
    result
}
pub(crate) fn cancel(id: &str) -> Result<(), BridgeError> {
    if let Some(entry) = lock(sessions())?.remove(id) {
        entry.cancelled.store(true, Ordering::Release);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    fn config() -> serde_json::Value {
        json!({"chapterIndex":0,"chapterTitle":"测试","viewportWidthPx":80,"viewportHeightPx":60,"paddingLeftPx":0,"paddingTopPx":0,"paddingRightPx":0,"paddingBottomPx":0,"lineHeightPx":20,"baselineOffsetPx":15})
    }
    fn start() -> String {
        let v: serde_json::Value = serde_json::from_str(
            &begin(&json!({"schemaVersion":1,"config":config()}).to_string()).unwrap(),
        )
        .unwrap();
        v["sessionId"].as_str().unwrap().into()
    }
    #[test]
    fn cancellation_is_idempotent_and_rejects_late_push() {
        let id = start();
        cancel(&id).unwrap();
        cancel(&id).unwrap();
        assert!(push(&id, r#"{"schemaVersion":1,"blocks":[]}"#).is_err());
        assert!(finish(&id).is_err());
    }
    #[test]
    fn invalid_batch_releases_session_without_repairing_input() {
        let id = start();
        assert!(push(&id, r#"{"schemaVersion":2,"blocks":[]}"#).is_err());
        assert!(!lock(sessions()).unwrap().contains_key(&id));
    }
    #[test]
    fn finish_returns_remaining_pages_and_releases_session() {
        let id = start();
        let block = json!({"type":"paragraph","value":{"text":"甲😀乙","clusters":["甲","😀","乙"],"clusterWidthsPx":[16,16,16],"style":{"colorArgb":-1,"fontSizePx":16},"chapterPosition":9}});
        push(
            &id,
            &json!({"schemaVersion":1,"blocks":[block]}).to_string(),
        )
        .unwrap();
        let v: serde_json::Value = serde_json::from_str(&finish(&id).unwrap()).unwrap();
        assert_eq!(v["pages"][0]["text"], "甲😀乙");
        use base64::{engine::general_purpose::STANDARD, Engine};
        let positions = STANDARD
            .decode(v["glyphs"]["positions"].as_str().unwrap())
            .unwrap();
        let index = v["pages"][0]["elements"][2].as_u64().unwrap() as usize;
        assert_eq!(
            u32::from_le_bytes(positions[index * 16..index * 16 + 4].try_into().unwrap()),
            12
        );
        assert!(!lock(sessions()).unwrap().contains_key(&id));
        assert!(finish(&id).is_err());
    }
    #[test]
    fn malformed_config_and_unknown_fields_do_not_allocate() {
        assert!(begin(r#"{"schemaVersion":1,"config":{}}"#).is_err());
        assert!(begin(&json!({"schemaVersion":2,"config":config()}).to_string()).is_err());
        assert!(
            begin(&json!({"schemaVersion":1,"config":config(),"oldEngine":true}).to_string())
                .is_err()
        );
    }
}
