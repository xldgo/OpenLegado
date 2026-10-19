//! BackstageWebView DOM 执行通道（SOURCE_DIFF P1 完整 DOM WebView）
//!
//! 对齐 Kotlin `BackstageWebView.getStrResponse` 的挂起-唤醒机制：
//! Rust 解析/JS 宿主发起请求 → 生成 key 入队并阻塞等待 →
//! Flutter 订阅事件流用真实 WebView 执行 → `submit` 回传结果唤醒。
//!
//! # 语义与边界
//! - 默认超时 60s（对齐 `BackstageWebView` withTimeout）；规则级 Mode.WebJs 用 10s
//! - 无订阅者时由调用方选择既有无头/载荷回退，通道不持有进程全局实例。
//! - 空结果允许唤醒（对齐原版 evaluateJavascript 返回 `""`/`null` 的可空语义）
//! - **边界**：真实 DOM、页内接口注入与缓存模式由平台执行器实现；
//!   本模块只处理请求、结果、取消和资源归属，不证明平台执行能力。

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Arc, Condvar, Mutex, Weak};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};

use crate::error::{LegadoError, LegadoResult};

/// 默认超时：60s（对齐 Kotlin BackstageWebView）
pub const DEFAULT_WEBVIEW_TIMEOUT: Duration = Duration::from_secs(60);

/// 规则级 Mode.WebJs / `@webjs` 超时：10s（对齐 AnalyzeRule.getWebJsResult）
pub const RULE_WEBVIEW_TIMEOUT: Duration = Duration::from_secs(10);

/// WebView 执行请求事件（推送给 Flutter 的载荷）
#[derive(Debug, Default, Clone, PartialEq, Serialize, Deserialize)]
pub struct WebViewRequest {
    /// 请求唯一标识（回传结果时使用）
    pub key: String,
    /// 动作：webView / webViewGetSource / webViewGetOverrideUrl
    pub action: String,
    pub html: String,
    pub url: String,
    pub js: String,
    #[serde(default)]
    pub source_regex: String,
    #[serde(default)]
    pub override_url_regex: String,
    #[serde(default)]
    pub cache_first: bool,
    #[serde(default)]
    pub delay_time: i64,
    /// 规则级 Mode.WebJs：注入 window.result，timeout 更短
    #[serde(default)]
    pub is_rule: bool,
    /// 规则级注入的 result JSON/文本（对齐 CacheManager webview_result）
    #[serde(default)]
    pub result: String,
    /// 当前 JS 执行上下文的书源 key（对齐上游 `tag=getSource()?.getKey()` 语义）
    ///
    /// 加法式字段（项 B/B1，设计文档 §2.2 G4）：Kotlin 侧非空时按 `is_rule`
    /// 同等口径注入 java/source/cache JavascriptInterface；旧端（不感知
    /// 本字段的反序列化器）经 `#[serde(default)]` 缺省为空串，兼容不破。
    #[serde(default)]
    pub source_key: String,
    /// 请求域已持有的 cookie 串（`k1=v1; k2=v2`，B4 由 Rust 侧按请求 URL 域
    /// 从 JS cookie store 取用后填入，Kotlin 侧 load 前经 CookieManager 写入）
    ///
    /// 加法式字段（项 B/B4）：同上，缺省空串兼容。
    #[serde(default)]
    pub cookie: String,
    #[serde(default)]
    pub headers: HashMap<String, String>,
    pub created_at_ms: u64,
}

/// 平台合成响应；不包含虚构的页面HTTP状态。
#[derive(Debug, Default, Clone, PartialEq)]
pub struct WebViewResponse {
    pub result: String,
    pub final_url: String,
    pub error: Option<String>,
}

/// 仅检查任务是否仍有效；实现必须为非阻塞数据检查，不得回调管理器。
pub type ActiveCheck = Arc<dyn Fn() -> bool + Send + Sync>;

enum Outcome {
    Done(WebViewResponse),
    Cancelled,
    TimedOut,
}
enum Phase {
    Pending,
    Completing,
    Finished(Outcome),
}
struct AttemptState {
    phase: Phase,
    deadline: Instant,
}
struct Attempt {
    page_calls: Mutex<()>,
    request: WebViewRequest,
    active: Option<ActiveCheck>,
    state: Mutex<AttemptState>,
    cond: Condvar,
    wake: tokio::sync::Notify,
}
impl Attempt {
    fn is_pending(&self) -> bool {
        let state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        matches!(state.phase, Phase::Pending)
            && Instant::now() < state.deadline
            && self.active.as_ref().is_none_or(|check| check())
    }
}
struct Subscriber {
    sender: Sender<WebViewRequest>,
    wake: Arc<tokio::sync::Notify>,
}
#[derive(Default)]
struct ManagerState {
    attempts: HashMap<String, Arc<Attempt>>,
    subscribers: HashMap<u64, Subscriber>,
    next_subscription: u64,
}

/// 同一宿主的数据通道；句柄拥有管理器，订阅只保留弱引用。
pub struct WebViewManager {
    id: u64,
    state: Mutex<ManagerState>,
    seq: AtomicU64,
}
static NEXT_MANAGER: AtomicU64 = AtomicU64::new(1);
impl Default for WebViewManager {
    fn default() -> Self {
        Self {
            id: NEXT_MANAGER.fetch_add(1, Ordering::Relaxed),
            state: Mutex::new(ManagerState::default()),
            seq: AtomicU64::new(0),
        }
    }
}
impl WebViewManager {
    pub fn has_subscribers(&self) -> bool {
        !self
            .state
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .subscribers
            .is_empty()
    }
    /// 显式请求入口供宿主和通道使用；不要求订阅者已经连接。
    pub fn request(self: &Arc<Self>, req: WebViewRequest) -> WebViewHandle {
        self.begin(req, DEFAULT_WEBVIEW_TIMEOUT, None, false)
            .expect("显式请求不检查订阅")
    }
    /// 检查订阅和入队在同一锁内，避免订阅刚退出后仍进入长等待。
    pub fn try_request(
        self: &Arc<Self>,
        req: WebViewRequest,
        timeout: Duration,
        active: Option<ActiveCheck>,
    ) -> Option<WebViewHandle> {
        self.begin(req, timeout, active, true)
    }
    fn begin(
        self: &Arc<Self>,
        mut req: WebViewRequest,
        timeout: Duration,
        active: Option<ActiveCheck>,
        require_subscriber: bool,
    ) -> Option<WebViewHandle> {
        let mut state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        if require_subscriber && state.subscribers.is_empty() {
            return None;
        }
        req.key = format!(
            "webview-{}-{}",
            self.id,
            self.seq.fetch_add(1, Ordering::Relaxed)
        );
        if req.created_at_ms == 0 {
            req.created_at_ms = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|d| d.as_millis() as u64)
                .unwrap_or(0);
        }
        let attempt = Arc::new(Attempt {
            page_calls: Mutex::new(()),
            request: req.clone(),
            active,
            state: Mutex::new(AttemptState {
                phase: Phase::Pending,
                deadline: Instant::now() + timeout,
            }),
            cond: Condvar::new(),
            wake: tokio::sync::Notify::new(),
        });
        state.attempts.insert(req.key.clone(), attempt.clone());
        state.subscribers.retain(|_, subscriber| {
            let sent = subscriber.sender.send(req.clone()).is_ok();
            if sent {
                subscriber.wake.notify_one();
            }
            sent
        });
        Some(WebViewHandle {
            attempt,
            manager: self.clone(),
        })
    }
    pub fn submit(&self, key: &str, result: &str) -> bool {
        self.submit_with(key, result, || {})
    }
    /// 原子认领后再执行副作用，不持请求表或状态锁进入数据库。
    /// 认领后完成方获胜，等待者须等提交结束；回调panic也会唤醒并清理。
    pub fn submit_with(&self, key: &str, result: &str, commit: impl FnOnce()) -> bool {
        self.submit_response_with(
            key,
            WebViewResponse {
                result: result.into(),
                ..Default::default()
            },
            commit,
        )
    }
    pub fn submit_response_with(
        &self,
        key: &str,
        mut response: WebViewResponse,
        commit: impl FnOnce(),
    ) -> bool {
        let Some(attempt) = self
            .state
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .attempts
            .get(key)
            .cloned()
        else {
            return false;
        };
        let _page_call = attempt.page_calls.lock().unwrap_or_else(|e| e.into_inner());
        let mut state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        let mut status = attempt.state.lock().unwrap_or_else(|e| e.into_inner());
        if !matches!(status.phase, Phase::Pending) {
            return false;
        }
        let invalid = if attempt.active.as_ref().is_some_and(|check| !check()) {
            Some(Outcome::Cancelled)
        } else if Instant::now() >= status.deadline {
            Some(Outcome::TimedOut)
        } else {
            None
        };
        if let Some(outcome) = invalid {
            status.phase = Phase::Finished(outcome);
            state.attempts.remove(key);
            attempt.cond.notify_all();
            attempt.wake.notify_waiters();
            Self::broadcast_cancel(&mut state, key);
            return false;
        }
        status.phase = Phase::Completing;
        state.attempts.remove(key);
        drop(status);
        drop(state);
        if response.final_url.is_empty() {
            response.final_url = attempt.request.url.clone();
        }
        let completion = Completion(attempt.clone());
        commit();
        completion.finish(Outcome::Done(response));
        true
    }

    /// 页内操作串行，但不持请求表/状态锁执行IO；结束回传等待已开始的操作。
    pub fn with_page_call<T>(
        &self,
        key: &str,
        call: impl FnOnce(&WebViewRequest, WebViewLease) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        let attempt = self
            .state
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .attempts
            .get(key)
            .cloned()
            .ok_or_else(|| LegadoError::Network("WebView请求不存在或已结束".into()))?;
        let _operation = attempt.page_calls.lock().unwrap_or_else(|e| e.into_inner());
        let lease = WebViewLease(Arc::downgrade(&attempt));
        lease.check()?;
        if attempt.request.html.is_empty()
            || (!attempt.request.is_rule && attempt.request.source_key.is_empty())
        {
            return Err(LegadoError::JsEngine("该WebView请求未开放页内宿主".into()));
        }
        let result = call(&attempt.request, lease.clone());
        lease.check()?;
        result
    }
    pub fn cancel(&self, key: &str) -> bool {
        self.end(key, Outcome::Cancelled)
    }
    fn end(&self, key: &str, outcome: Outcome) -> bool {
        let mut state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        let Some(attempt) = state.attempts.remove(key) else {
            return false;
        };
        let mut status = attempt.state.lock().unwrap_or_else(|e| e.into_inner());
        status.phase = Phase::Finished(outcome);
        attempt.cond.notify_all();
        attempt.wake.notify_waiters();
        Self::broadcast_cancel(&mut state, key);
        true
    }
    fn broadcast_cancel(state: &mut ManagerState, key: &str) {
        let event = WebViewRequest {
            key: key.into(),
            action: "cancel".into(),
            ..Default::default()
        };
        state.subscribers.retain(|_, subscriber| {
            let sent = subscriber.sender.send(event.clone()).is_ok();
            if sent {
                subscriber.wake.notify_one();
            }
            sent
        });
    }
    pub fn subscribe(self: &Arc<Self>) -> WebViewSubscription {
        let (sender, receiver) = channel();
        let mut state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        let id = state.next_subscription;
        state.next_subscription += 1;
        let wake = Arc::new(tokio::sync::Notify::new());
        state.subscribers.insert(
            id,
            Subscriber {
                sender: sender.clone(),
                wake: wake.clone(),
            },
        );
        let mut replay: Vec<_> = state
            .attempts
            .values()
            .filter(|attempt| {
                let status = attempt.state.lock().unwrap_or_else(|e| e.into_inner());
                matches!(status.phase, Phase::Pending)
                    && Instant::now() < status.deadline
                    && attempt.active.as_ref().is_none_or(|check| check())
            })
            .map(|attempt| attempt.request.clone())
            .collect();
        replay.sort_by(|a, b| a.key.cmp(&b.key));
        for request in replay {
            let _ = sender.send(request);
            wake.notify_one();
        }
        WebViewSubscription {
            receiver,
            manager: Arc::downgrade(self),
            id,
            wake,
        }
    }
    fn is_pending(&self, key: &str) -> bool {
        self.state
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .attempts
            .get(key)
            .is_some_and(|attempt| attempt.is_pending())
    }
    pub fn pending(&self) -> Vec<WebViewRequest> {
        let state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        let mut requests: Vec<_> = state
            .attempts
            .values()
            .filter(|attempt| {
                let status = attempt.state.lock().unwrap_or_else(|e| e.into_inner());
                matches!(status.phase, Phase::Pending)
                    && Instant::now() < status.deadline
                    && attempt.active.as_ref().is_none_or(|check| check())
            })
            .map(|attempt| attempt.request.clone())
            .collect();
        requests.sort_by(|a, b| a.key.cmp(&b.key));
        requests
    }
}

/// 只保留请求弱引用，供页内IO取消及副作用前检查；不持引擎或平台对象。
#[derive(Clone)]
pub struct WebViewLease(Weak<Attempt>);
impl WebViewLease {
    pub fn is_active(&self) -> bool {
        self.0.upgrade().is_some_and(|a| a.is_pending())
    }
    pub fn check(&self) -> LegadoResult<()> {
        if self.is_active() {
            Ok(())
        } else {
            Err(LegadoError::Network("WebView请求已结束或取消".into()))
        }
    }
    pub async fn cancelled(&self) {
        loop {
            let Some(attempt) = self.0.upgrade() else {
                return;
            };
            let wake = attempt.wake.notified();
            tokio::pin!(wake);
            wake.as_mut().enable();
            if !attempt.is_pending() {
                return;
            }
            let deadline = attempt
                .state
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .deadline;
            let _ = tokio::time::timeout(deadline.saturating_duration_since(Instant::now()), wake)
                .await;
        }
    }
}

/// 完成屏障：已认领请求的副作用执行结束后才发布结果。
struct Completion(Arc<Attempt>);
impl Completion {
    fn finish(self, outcome: Outcome) {
        let mut state = self.0.state.lock().unwrap_or_else(|e| e.into_inner());
        state.phase = Phase::Finished(outcome);
        self.0.cond.notify_all();
        self.0.wake.notify_waiters();
    }
}
impl Drop for Completion {
    fn drop(&mut self) {
        let mut state = self.0.state.lock().unwrap_or_else(|e| e.into_inner());
        if matches!(state.phase, Phase::Completing) {
            state.phase = Phase::Finished(Outcome::Cancelled);
            self.0.cond.notify_all();
            self.0.wake.notify_waiters();
        }
    }
}

pub struct WebViewSubscription {
    receiver: Receiver<WebViewRequest>,
    manager: Weak<WebViewManager>,
    id: u64,
    wake: Arc<tokio::sync::Notify>,
}
impl WebViewSubscription {
    pub async fn recv_async(&mut self) -> Option<WebViewRequest> {
        loop {
            let wake = self.wake.notified();
            tokio::pin!(wake);
            wake.as_mut().enable();
            match self.try_recv() {
                Ok(request) => return Some(request),
                Err(std::sync::mpsc::TryRecvError::Disconnected) => return None,
                Err(std::sync::mpsc::TryRecvError::Empty) => wake.await,
            }
        }
    }
}
impl Drop for WebViewManager {
    fn drop(&mut self) {
        let state = self.state.get_mut().unwrap_or_else(|e| e.into_inner());
        for (_, subscriber) in state.subscribers.drain() {
            drop(subscriber.sender);
            subscriber.wake.notify_one();
        }
    }
}

impl WebViewSubscription {
    pub fn try_recv(&self) -> Result<WebViewRequest, std::sync::mpsc::TryRecvError> {
        loop {
            let request = self.receiver.try_recv()?;
            let Some(manager) = self.manager.upgrade() else {
                return Err(std::sync::mpsc::TryRecvError::Disconnected);
            };
            if request.action == "cancel" || manager.is_pending(&request.key) {
                return Ok(request);
            }
        }
    }
    pub fn recv_timeout(
        &self,
        timeout: Duration,
    ) -> Result<WebViewRequest, std::sync::mpsc::RecvTimeoutError> {
        let deadline = Instant::now() + timeout;
        loop {
            let request = self
                .receiver
                .recv_timeout(deadline.saturating_duration_since(Instant::now()))?;
            let Some(manager) = self.manager.upgrade() else {
                return Err(std::sync::mpsc::RecvTimeoutError::Disconnected);
            };
            if request.action == "cancel" || manager.is_pending(&request.key) {
                return Ok(request);
            }
        }
    }
}
impl Drop for WebViewSubscription {
    fn drop(&mut self) {
        if let Some(manager) = self.manager.upgrade() {
            let keys = {
                let mut state = manager.state.lock().unwrap_or_else(|e| e.into_inner());
                state.subscribers.remove(&self.id);
                if state.subscribers.is_empty() {
                    state.attempts.keys().cloned().collect::<Vec<_>>()
                } else {
                    Vec::new()
                }
            };
            for key in keys {
                manager.cancel(&key);
            }
        }
    }
}

/// 句柄丢弃即放弃待处理请求，不等待Flutter或保留静态引用。
pub struct WebViewHandle {
    attempt: Arc<Attempt>,
    manager: Arc<WebViewManager>,
}
impl WebViewHandle {
    pub fn key(&self) -> &str {
        &self.attempt.request.key
    }
    /// 异步等待不占用运行时工作线程；丢弃future将由句柄Drop取消平台请求。
    pub async fn wait_async(self, timeout: Duration) -> LegadoResult<WebViewResponse> {
        {
            let mut state = self.attempt.state.lock().unwrap_or_else(|e| e.into_inner());
            state.deadline = state.deadline.min(Instant::now() + timeout);
        }
        loop {
            let wake = self.attempt.wake.notified();
            tokio::pin!(wake);
            wake.as_mut().enable();
            let (completing, deadline, active) = {
                let state = self.attempt.state.lock().unwrap_or_else(|e| e.into_inner());
                match &state.phase {
                    Phase::Finished(Outcome::Done(response)) => {
                        if let Some(error) = &response.error {
                            return Err(LegadoError::Network(error.clone()));
                        }
                        return Ok(response.clone());
                    }
                    Phase::Finished(Outcome::Cancelled) => {
                        return Err(LegadoError::Network("WebView请求已取消".into()));
                    }
                    Phase::Finished(Outcome::TimedOut) => {
                        return Err(LegadoError::Timeout("webview execution timed out".into()));
                    }
                    _ => {}
                }
                (
                    matches!(state.phase, Phase::Completing),
                    state.deadline,
                    self.attempt.active.as_ref().is_none_or(|check| check()),
                )
            };
            if completing {
                wake.await;
            } else if !active {
                self.manager.end(self.key(), Outcome::Cancelled);
            } else if Instant::now() >= deadline {
                self.manager.end(self.key(), Outcome::TimedOut);
            } else {
                let _ =
                    tokio::time::timeout(deadline.saturating_duration_since(Instant::now()), wake)
                        .await;
            }
        }
    }
    pub fn wait(self, timeout: Duration) -> LegadoResult<String> {
        self.wait_response(timeout).map(|response| response.result)
    }
    pub fn wait_response(self, timeout: Duration) -> LegadoResult<WebViewResponse> {
        let mut state = self.attempt.state.lock().unwrap_or_else(|e| e.into_inner());
        state.deadline = state.deadline.min(Instant::now() + timeout);
        loop {
            match &state.phase {
                Phase::Finished(Outcome::Done(response)) => {
                    if let Some(error) = &response.error {
                        return Err(LegadoError::Network(error.clone()));
                    }
                    return Ok(response.clone());
                }
                Phase::Finished(Outcome::Cancelled) => {
                    return Err(LegadoError::Network("WebView请求已取消".into()));
                }
                Phase::Finished(Outcome::TimedOut) => {
                    return Err(LegadoError::Timeout("webview execution timed out".into()));
                }
                Phase::Completing => {
                    state = self
                        .attempt
                        .cond
                        .wait(state)
                        .unwrap_or_else(|e| e.into_inner());
                    continue;
                }
                Phase::Pending => {}
            }
            let cancelled = self.attempt.active.as_ref().is_some_and(|check| !check());
            let now = Instant::now();
            if cancelled || now >= state.deadline {
                drop(state);
                self.manager.end(
                    self.key(),
                    if cancelled {
                        Outcome::Cancelled
                    } else {
                        Outcome::TimedOut
                    },
                );
                state = self.attempt.state.lock().unwrap_or_else(|e| e.into_inner());
                continue;
            }
            // 同步JS已占阻塞工作线程；仅绑定任务时短等待检查取消，不新增监视线程。
            let remaining = state.deadline - now;
            let delay = if self.attempt.active.is_some() {
                remaining.min(Duration::from_millis(10))
            } else {
                remaining
            };
            state = self
                .attempt
                .cond
                .wait_timeout(state, delay)
                .unwrap_or_else(|e| e.into_inner())
                .0;
        }
    }
}
impl Drop for WebViewHandle {
    fn drop(&mut self) {
        self.manager.cancel(self.key());
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;

    /// B1 加法式字段：旧 JSON（无 source_key/cookie）反序列化缺省为空串，兼容不破
    #[test]
    fn legacy_json_without_new_fields_deserializes() {
        let legacy = r#"{
            "key": "webview-1-0",
            "action": "webView",
            "html": "<p>x</p>",
            "url": "https://example.com",
            "js": "document.body.innerText",
            "source_regex": "",
            "override_url_regex": "",
            "cache_first": false,
            "delay_time": 0,
            "is_rule": false,
            "result": "",
            "created_at_ms": 1
        }"#;
        let req: WebViewRequest = serde_json::from_str(legacy).unwrap();
        assert_eq!(req.source_key, String::new());
        assert_eq!(req.cookie, String::new());
    }

    /// B1 加法式字段：含新字段的 JSON 往返（round-trip）保持
    #[test]
    fn new_fields_round_trip() {
        let req = WebViewRequest {
            key: "webview-2-0".into(),
            action: "webViewGetSource".into(),
            html: String::new(),
            url: "https://a.example.com".into(),
            js: String::new(),
            source_regex: "x".into(),
            override_url_regex: String::new(),
            cache_first: false,
            delay_time: 0,
            is_rule: false,
            result: String::new(),
            source_key: "https://source.example.com".into(),
            cookie: "acw_tc=1; session=2".into(),
            headers: Default::default(),
            created_at_ms: 7,
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("\"source_key\""));
        assert!(json.contains("\"cookie\""));
        let back: WebViewRequest = serde_json::from_str(&json).unwrap();
        assert_eq!(back, req);
    }

    #[test]
    fn submit_wakes_waiter() {
        let mgr = Arc::new(WebViewManager::default());
        let rx = mgr.subscribe();
        let handle = mgr.request(WebViewRequest {
            key: String::new(),
            action: "webView".into(),
            html: "<p>hi</p>".into(),
            url: "https://example.com".into(),
            js: "document.body.innerText".into(),
            source_regex: String::new(),
            override_url_regex: String::new(),
            cache_first: true,
            delay_time: 0,
            is_rule: true,
            result: "\"x\"".into(),
            source_key: String::new(),
            cookie: String::new(),
            headers: Default::default(),
            created_at_ms: 0,
        });
        let key = handle.key().to_string();
        let waiter = thread::spawn(move || handle.wait(Duration::from_secs(5)));
        let evt = rx.recv_timeout(Duration::from_secs(2)).expect("event");
        assert_eq!(evt.key, key);
        assert!(mgr.submit(&key, "from-dom"));
        assert_eq!(waiter.join().unwrap().unwrap(), "from-dom");
    }

    fn request_fixture() -> WebViewRequest {
        serde_json::from_value(serde_json::json!({
            "key":"", "action":"webView", "html":"", "url":"https://view.test/",
            "js":"", "is_rule":false, "result":"", "created_at_ms":0
        }))
        .unwrap()
    }

    #[test]
    fn cancelled_request_is_not_a_successful_empty_result() {
        let manager = Arc::new(WebViewManager::default());
        let handle = manager.request(request_fixture());
        assert!(manager.cancel(handle.key()));
        assert!(handle.wait(Duration::from_millis(10)).is_err());
    }

    #[test]
    fn dropping_handle_removes_pending_request() {
        let manager = Arc::new(WebViewManager::default());
        let handle = manager.request(request_fixture());
        drop(handle);
        assert!(manager.pending().is_empty());
    }

    #[test]
    fn dropping_subscriber_removes_capability() {
        let manager = Arc::new(WebViewManager::default());
        let subscription = manager.subscribe();
        assert!(manager.has_subscribers());
        drop(subscription);
        assert!(!manager.has_subscribers());
    }

    #[test]
    fn completion_claim_is_unique_and_waiter_observes_committed_effect() {
        let manager = Arc::new(WebViewManager::default());
        let handle = manager.request(request_fixture());
        let key = handle.key().to_string();
        let claimed = manager.clone();
        let claim_key = key.clone();
        let (entered, ready) = channel();
        let (release, gate) = channel();
        let written = Arc::new(std::sync::atomic::AtomicBool::new(false));
        let effect = written.clone();
        let writer = thread::spawn(move || {
            claimed.submit_with(&claim_key, "done", || {
                entered.send(()).unwrap();
                gate.recv().unwrap();
                effect.store(true, Ordering::SeqCst);
            })
        });
        ready.recv_timeout(Duration::from_secs(2)).unwrap();
        assert!(!manager.cancel(&key));
        assert!(!manager.submit(&key, "duplicate"));
        let (result, received) = channel();
        let waiter = thread::spawn(move || {
            let value = handle.wait(Duration::ZERO);
            result
                .send((value, written.load(Ordering::SeqCst)))
                .unwrap();
        });
        assert!(matches!(
            received.recv_timeout(Duration::from_millis(20)),
            Err(std::sync::mpsc::RecvTimeoutError::Timeout)
        ));
        release.send(()).unwrap();
        assert!(writer.join().unwrap());
        waiter.join().unwrap();
        let (value, written) = received.recv().unwrap();
        assert_eq!(value.unwrap(), "done");
        assert!(written);
        assert!(manager.pending().is_empty());
    }

    #[test]
    fn invalid_or_duplicate_results_never_run_effect_and_empty_success_is_preserved() {
        let manager = Arc::new(WebViewManager::default());
        let mut effects = 0;
        assert!(!manager.submit_with("unknown", "", || effects += 1));
        let request = manager.request(request_fixture());
        let key = request.key().to_string();
        assert!(manager.cancel(&key));
        assert!(!manager.submit_with(&key, "late", || effects += 1));
        drop(request);
        let request = manager.request(request_fixture());
        let key = request.key().to_string();
        assert!(request.wait(Duration::ZERO).is_err());
        assert!(!manager.submit_with(&key, "late", || effects += 1));
        let subscription = manager.subscribe();
        let request = manager
            .try_request(request_fixture(), Duration::ZERO, None)
            .unwrap();
        assert!(!manager.submit_with(request.key(), "expired", || effects += 1));
        assert!(matches!(
            request.wait(Duration::ZERO),
            Err(LegadoError::Timeout(_))
        ));
        let active = Arc::new(std::sync::atomic::AtomicBool::new(true));
        let check = active.clone();
        let request = manager
            .try_request(
                request_fixture(),
                Duration::from_secs(2),
                Some(Arc::new(move || check.load(Ordering::SeqCst))),
            )
            .unwrap();
        active.store(false, Ordering::SeqCst);
        assert!(!manager.submit_with(request.key(), "cancelled", || effects += 1));
        assert!(request.wait(Duration::from_secs(2)).is_err());
        let request = manager.request(request_fixture());
        let key = request.key().to_string();
        assert!(manager.submit_with(&key, "", || effects += 1));
        assert_eq!(request.wait(Duration::from_secs(2)).unwrap(), "");
        assert!(!manager.submit_with(&key, "duplicate", || effects += 1));
        assert_eq!(effects, 1);
        drop(subscription);
    }

    #[test]
    fn last_subscriber_cancels_waiting_requests_and_instances_do_not_cross() {
        let one = Arc::new(WebViewManager::default());
        let two = Arc::new(WebViewManager::default());
        let first = one.subscribe();
        let second = one.subscribe();
        let other = two.subscribe();
        let a = one.request(request_fixture());
        let b = two.request(request_fixture());
        assert_ne!(a.key(), b.key());
        assert_eq!(
            first.recv_timeout(Duration::from_secs(1)).unwrap().key,
            a.key()
        );
        assert_eq!(
            other.recv_timeout(Duration::from_secs(1)).unwrap().key,
            b.key()
        );
        assert!(!two.submit(a.key(), "wrong"));
        drop(first);
        assert!(one.has_subscribers());
        assert_eq!(one.pending().len(), 1);
        drop(second);
        assert!(one.pending().is_empty());
        assert!(a.wait(Duration::from_secs(1)).is_err());
        assert!(two.submit(b.key(), "two"));
        assert_eq!(b.wait(Duration::from_secs(1)).unwrap(), "two");
    }

    #[tokio::test]
    async fn subscription_replays_pending_once_and_does_not_keep_manager_alive() {
        let manager = Arc::new(WebViewManager::default());
        let weak = Arc::downgrade(&manager);
        let handle = manager.request(request_fixture());
        let mut subscription = manager.subscribe();
        let request = subscription.recv_async().await.unwrap();
        assert_eq!(request.key, handle.key());
        assert!(matches!(
            subscription.try_recv(),
            Err(std::sync::mpsc::TryRecvError::Empty)
        ));
        drop(handle);
        drop(manager);
        assert!(weak.upgrade().is_none());
        assert!(subscription.recv_async().await.is_none());
    }

    #[test]
    fn effect_panic_releases_completion_barrier_and_manager_can_be_reused() {
        let manager = Arc::new(WebViewManager::default());
        let handle = manager.request(request_fixture());
        assert!(
            std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                manager.submit_with(handle.key(), "", || panic!("模拟写入异常"))
            }))
            .is_err()
        );
        assert!(handle.wait(Duration::from_secs(1)).is_err());
        assert!(manager.pending().is_empty());
        let next = manager.request(request_fixture());
        assert!(manager.submit(next.key(), "ok"));
        assert_eq!(next.wait(Duration::from_secs(1)).unwrap(), "ok");
    }
    #[tokio::test]
    async fn cancelled_queued_events_are_not_dispatched_to_subscriber() {
        let manager = Arc::new(WebViewManager::default());
        let mut subscriber = manager.subscribe();
        let old = manager.request(request_fixture());
        manager.cancel(old.key());
        let live = manager.request(request_fixture());
        let cancelled = subscriber.recv_async().await.unwrap();
        assert_eq!(cancelled.action, "cancel");
        assert_eq!(cancelled.key, old.key());
        assert_eq!(subscriber.recv_async().await.unwrap().key, live.key());
        assert!(manager.submit(live.key(), "live"));
        assert_eq!(live.wait(Duration::from_secs(1)).unwrap(), "live");
        assert!(old.wait(Duration::from_secs(1)).is_err());
    }

    #[tokio::test]
    async fn async_wait_yields_preserves_final_url_and_drop_notifies_platform() {
        let manager = Arc::new(WebViewManager::default());
        let mut subscription = manager.subscribe();
        let handle = manager.request(request_fixture());
        let key = handle.key().to_owned();
        let waiting = tokio::spawn(handle.wait_async(Duration::from_secs(1)));
        assert_eq!(subscription.recv_async().await.unwrap().key, key);
        tokio::task::yield_now().await;
        assert!(!waiting.is_finished());
        assert!(manager.submit_response_with(
            &key,
            WebViewResponse {
                result: String::new(),
                final_url: "https://final.test/".into(),
                error: None,
            },
            || {}
        ));
        assert_eq!(
            waiting.await.unwrap().unwrap().final_url,
            "https://final.test/"
        );
        let next = manager.request(request_fixture());
        let key = next.key().to_owned();
        drop(next.wait_async(Duration::from_secs(1)));
        let event = subscription.recv_async().await.unwrap();
        assert_eq!(event.action, "cancel");
        assert_eq!(event.key, key);
        assert!(event.cookie.is_empty() && event.headers.is_empty() && event.html.is_empty());
        assert!(!manager.submit(&key, "迟到"));
    }

    #[tokio::test]
    async fn async_timeout_and_platform_failure_remain_errors() {
        let manager = Arc::new(WebViewManager::default());
        let mut subscription = manager.subscribe();
        let handle = manager.request(request_fixture());
        assert!(matches!(
            handle.wait_async(Duration::ZERO).await,
            Err(LegadoError::Timeout(_))
        ));
        assert_eq!(subscription.recv_async().await.unwrap().action, "cancel");
        let handle = manager.request(request_fixture());
        assert!(manager.submit_response_with(
            handle.key(),
            WebViewResponse {
                error: Some("加载失败".into()),
                ..Default::default()
            },
            || {}
        ));
        assert!(
            handle
                .wait_async(Duration::from_secs(1))
                .await
                .unwrap_err()
                .to_string()
                .contains("加载失败")
        );
    }
    #[test]
    fn page_calls_are_owned_by_live_request_and_completion_waits_for_them() {
        let manager = Arc::new(WebViewManager::default());
        let request = WebViewRequest {
            html: "<html>".into(),
            source_key: "source-one".into(),
            ..Default::default()
        };
        let handle = manager.request(request);
        let key = handle.key().to_owned();
        let other = Arc::new(WebViewManager::default());
        assert!(other.with_page_call(&key, |_, _| Ok(())).is_err());
        let (entered, ready) = std::sync::mpsc::channel();
        let (release, released) = std::sync::mpsc::channel();
        let thread = {
            let manager = manager.clone();
            let key = key.clone();
            std::thread::spawn(move || {
                manager.with_page_call(&key, |request, lease| {
                    assert_eq!(request.source_key, "source-one");
                    entered.send(lease).unwrap();
                    released.recv().unwrap();
                    Ok(())
                })
            })
        };
        let lease = ready.recv().unwrap();
        let (done, finished) = std::sync::mpsc::channel();
        let submit = {
            let manager = manager.clone();
            let key = key.clone();
            std::thread::spawn(move || {
                done.send(manager.submit(&key, "done")).unwrap();
            })
        };
        assert!(finished.recv_timeout(Duration::from_millis(30)).is_err());
        assert!(lease.is_active());
        release.send(()).unwrap();
        thread.join().unwrap().unwrap();
        assert!(finished.recv().unwrap());
        submit.join().unwrap();
        assert_eq!(handle.wait(Duration::from_secs(1)).unwrap(), "done");
        assert!(!lease.is_active());
        assert!(
            manager
                .with_page_call::<()>(&key, |_, _| panic!("结束后不得调用"))
                .is_err()
        );
    }
    #[tokio::test]
    async fn page_io_cancellation_wakes_without_waiting_for_operation_lock() {
        let manager = Arc::new(WebViewManager::default());
        let handle = manager.request(WebViewRequest {
            html: "<html>".into(),
            is_rule: true,
            ..Default::default()
        });
        let key = handle.key().to_owned();
        let lease = manager.with_page_call(&key, |_, lease| Ok(lease)).unwrap();
        let waiter = tokio::spawn(async move {
            lease.cancelled().await;
            assert!(!lease.is_active());
        });
        manager.cancel(&key);
        tokio::time::timeout(Duration::from_secs(1), waiter)
            .await
            .unwrap()
            .unwrap();
        assert!(
            manager
                .with_page_call::<()>(&key, |_, _| panic!("取消后不得调用"))
                .is_err()
        );
        let handle = manager.request(WebViewRequest::default());
        assert!(
            manager
                .with_page_call::<()>(handle.key(), |_, _| panic!("URL页面没有页内宿主"))
                .is_err()
        );
    }
}
