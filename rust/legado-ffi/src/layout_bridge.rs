//! 排版句柄拥有状态和容量许可；不以进程字符串表查找会话。— Codex + Bridge
use crate::{
    ffi::BridgeError,
    layout_dto::{LayoutBlockDto, LayoutConfigDto, LayoutReplyDto},
};
use legado_layout::{
    model::Block,
    paginator::{PaginationSession, validate_block},
};
use std::{
    sync::{
        Mutex,
        atomic::{AtomicBool, AtomicUsize, Ordering},
    },
    time::Instant,
};
const MAX_SESSIONS: usize = 8;
const MAX_BATCH_BLOCKS: usize = 32;
const MAX_BATCH_ITEMS: usize = 250_000;
const MAX_PAYLOAD_BYTES: usize = 16 * 1024 * 1024;
static LIVE_SESSIONS: AtomicUsize = AtomicUsize::new(0);
fn error(message: impl ToString) -> BridgeError {
    BridgeError {
        message: message.to_string(),
    }
}
struct Permit;
impl Permit {
    fn acquire() -> Result<Self, BridgeError> {
        LIVE_SESSIONS
            .try_update(Ordering::AcqRel, Ordering::Acquire, |n| {
                (n < MAX_SESSIONS).then_some(n + 1)
            })
            .map(|_| Self)
            .map_err(|_| error("阅读布局会话达到上限，请取消旧会话"))
    }
}
impl Drop for Permit {
    fn drop(&mut self) {
        LIVE_SESSIONS.fetch_sub(1, Ordering::AcqRel);
    }
}
struct State {
    core: PaginationSession,
    _permit: Permit,
}
#[flutter_rust_bridge::frb(opaque)]
pub struct LayoutSession {
    state: Mutex<Option<State>>,
    cancelled: std::sync::Arc<AtomicBool>,
}
impl LayoutSession {
    pub(crate) fn begin(config: LayoutConfigDto) -> Result<Self, BridgeError> {
        config.check_budget(&mut PayloadBudget { bytes: 0, nodes: 0 }, 0)?;
        let permit = Permit::acquire()?;
        let mut core = PaginationSession::new(config.try_into()?).map_err(error)?;
        let cancelled = std::sync::Arc::new(AtomicBool::new(false));
        core.set_cancellation(cancelled.clone());
        Ok(Self {
            state: Mutex::new(Some(State {
                core,
                _permit: permit,
            })),
            cancelled,
        })
    }
    /// 独立取消标志先发布；长计算持有状态锁时也能立即取消。
    #[flutter_rust_bridge::frb(sync)]
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::Release);
        if let Ok(mut state) = self.state.try_lock() {
            state.take();
        }
    }
    pub fn push(&self, blocks: Vec<LayoutBlockDto>) -> Result<LayoutReplyDto, BridgeError> {
        let start = Instant::now();
        let result = self.push_inner(blocks, start);
        if result.is_err() {
            self.cancel();
        }
        result
    }
    fn push_inner(
        &self,
        blocks: Vec<LayoutBlockDto>,
        start: Instant,
    ) -> Result<LayoutReplyDto, BridgeError> {
        if self.cancelled.load(Ordering::Acquire) {
            return Err(error("阅读布局会话已取消"));
        }
        if blocks.len() > MAX_BATCH_BLOCKS {
            return Err(error("阅读布局单批内容块超过32"));
        }
        // DTO 克隆/转换前检查递归载荷预算，避免深树与超大文本进入排版。
        let mut budget = PayloadBudget { bytes: 0, nodes: 0 };
        for block in &blocks {
            block.check_budget(&mut budget, 0)?;
        }
        let blocks: Vec<Block> = blocks
            .into_iter()
            .map(TryInto::try_into)
            .collect::<Result<_, _>>()?;
        let count: usize = blocks
            .iter()
            .map(|b| match b {
                Block::Paragraph { value } => value.clusters.len(),
                Block::InlineParagraph(v) => v.items.len(),
                _ => 1,
            })
            .sum();
        if count > MAX_BATCH_ITEMS {
            return Err(error("阅读布局单批行内项超过250000"));
        }
        for block in &blocks {
            validate_block(block).map_err(error)?;
        }
        let mut slot = self.state.lock().map_err(|_| error("阅读布局会话锁损坏"))?;
        let state = slot
            .as_mut()
            .ok_or_else(|| error("阅读布局会话已完成或取消"))?;
        let result = (|| {
            let mut pages = vec![];
            for block in blocks {
                pages.extend(state.core.accept(block).map_err(error)?);
            }
            if self.cancelled.load(Ordering::Acquire) {
                return Err(error("阅读布局会话已取消"));
            }
            Ok(LayoutReplyDto::pack(pages, start))
        })();
        if result.is_err() {
            slot.take();
        }
        result
    }
    pub fn finish(&self) -> Result<LayoutReplyDto, BridgeError> {
        let start = Instant::now();
        let mut slot = self.state.lock().map_err(|_| error("阅读布局会话锁损坏"))?;
        let mut state = slot
            .take()
            .ok_or_else(|| error("阅读布局会话已完成或取消"))?;
        if self.cancelled.load(Ordering::Acquire) {
            return Err(error("阅读布局会话已取消"));
        }
        let pages = state.core.finish().map_err(error)?;
        if self.cancelled.load(Ordering::Acquire) {
            return Err(error("阅读布局会话已取消"));
        }
        Ok(LayoutReplyDto::pack(pages, start))
    }
}
impl Drop for LayoutSession {
    fn drop(&mut self) {
        self.cancelled.store(true, Ordering::Release);
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub(crate) struct PayloadBudget {
    bytes: usize,
    nodes: usize,
}
impl PayloadBudget {
    pub(crate) fn add(&mut self, bytes: usize, depth: usize) -> Result<(), BridgeError> {
        self.bytes = self.bytes.saturating_add(bytes);
        self.nodes += 1;
        if self.bytes > MAX_PAYLOAD_BYTES || self.nodes > 2_000_000 || depth > 64 {
            Err(error("阅读布局载荷超过预算或嵌套过深"))
        } else {
            Ok(())
        }
    }
}
#[flutter_rust_bridge::frb(ignore)]
pub(crate) trait Budget {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, budget: &mut PayloadBudget, depth: usize) -> Result<(), BridgeError>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use legado_layout::model::{Block, Config};
    use serde_json::json;
    static LOCK: Mutex<()> = Mutex::new(());
    fn config() -> LayoutConfigDto {
        serde_json::from_value::<Config>(json!({
            "chapterIndex":0,"chapterTitle":"测试","viewportWidthPx":320,
            "viewportHeightPx":480,"paddingLeftPx":10,"paddingTopPx":10,
            "paddingRightPx":10,"paddingBottomPx":10,"lineHeightPx":24,
            "baselineOffsetPx":18
        }))
        .unwrap()
        .into()
    }
    fn paragraph() -> LayoutBlockDto {
        serde_json::from_value::<Block>(json!({"type":"paragraph","value":{
            "text":"甲😀乙","clusters":["甲","😀","乙"],"clusterWidthsPx":[20,24,20],
            "style":{"colorArgb":-1,"fontSizePx":20},"chapterPosition":3
        }}))
        .unwrap()
        .into()
    }
    #[test]
    fn finish_returns_binary_columns_and_releases_capacity() {
        let _guard = LOCK.lock().unwrap();
        let before = LIVE_SESSIONS.load(Ordering::Acquire);
        let session = LayoutSession::begin(config()).unwrap();
        let first = session.push(vec![paragraph()]).unwrap();
        let last = session.finish().unwrap();
        assert_eq!(first.text + &last.text, "甲😀乙");
        assert_eq!(last.geometry.len(), last.count * 5 * 4);
        assert_eq!(last.positions.len(), last.count * 4 * 4);
        assert_eq!(LIVE_SESSIONS.load(Ordering::Acquire), before);
        assert!(session.push(vec![]).is_err());
        assert!(session.finish().is_err());
        session.cancel();
    }
    #[test]
    fn capacity_is_owned_and_drop_cancel_and_invalid_push_release_once() {
        let _guard = LOCK.lock().unwrap();
        assert_eq!(LIVE_SESSIONS.load(Ordering::Acquire), 0);
        let mut sessions: Vec<_> = (0..MAX_SESSIONS)
            .map(|_| LayoutSession::begin(config()).unwrap())
            .collect();
        assert!(LayoutSession::begin(config()).is_err());
        let cancelled = sessions.pop().unwrap();
        cancelled.cancel();
        cancelled.cancel();
        assert!(cancelled.push(vec![paragraph()]).is_err());
        let replacement = LayoutSession::begin(config()).unwrap();
        assert!(
            replacement
                .push((0..33).map(|_| paragraph()).collect())
                .is_err()
        );
        assert_eq!(LIVE_SESSIONS.load(Ordering::Acquire), MAX_SESSIONS - 1);
        drop(sessions);
        drop(replacement);
        drop(cancelled);
        assert_eq!(LIVE_SESSIONS.load(Ordering::Acquire), 0);
    }
    #[test]
    fn invalid_config_and_deep_payload_do_not_leak_permits() {
        let _guard = LOCK.lock().unwrap();
        let mut invalid = config();
        invalid.viewport_width_px = 0;
        assert!(LayoutSession::begin(invalid).is_err());
        let mut deep = crate::layout_dto::LayoutValueDto::from(json!("底部"));
        for _ in 0..70 {
            deep = crate::layout_dto::LayoutValueDto {
                kind: crate::layout_dto::LayoutValueKind::Array,
                array: vec![deep],
                ..crate::layout_dto::LayoutValueDto::from(serde_json::Value::Null)
            };
        }
        let mut oversized = config();
        oversized.decoration = deep;
        assert!(LayoutSession::begin(oversized).is_err());
        assert_eq!(LIVE_SESSIONS.load(Ordering::Acquire), 0);
    }
    #[test]
    fn upstream_config_and_every_content_variant_survive_typed_roundtrip() {
        let fixture: serde_json::Value =
            serde_json::from_str(include_str!("../tests/fixtures/layout_transport.json")).unwrap();
        let mut checked = 0;
        for case in fixture["cases"].as_array().unwrap() {
            let Some(config_value) = case["input"].get("config") else {
                continue;
            };
            let config: Config = serde_json::from_value(config_value.clone()).unwrap();
            let expected = serde_json::to_value(&config).unwrap();
            let restored: Config = LayoutConfigDto::from(config).try_into().unwrap();
            assert_eq!(
                serde_json::to_value(restored).unwrap(),
                expected,
                "{}",
                case["name"]
            );
            for block_value in case["input"]["blocks"].as_array().unwrap() {
                let block: Block = serde_json::from_value(block_value.clone()).unwrap();
                let expected = serde_json::to_value(&block).unwrap();
                let restored: Block = LayoutBlockDto::from(block).try_into().unwrap();
                assert_eq!(
                    serde_json::to_value(restored).unwrap(),
                    expected,
                    "{}",
                    case["name"]
                );
                checked += 1;
            }
        }
        assert!(checked > 50, "应覆盖上游多个内容块样本");
    }
}
