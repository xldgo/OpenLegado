//! VM 可持有的来源登录数据能力；不依赖数据库、宿主或根引擎。

/// 与既有 loginHeader_ / userInfo_ 缓存键一一对应。
#[derive(Clone, Copy)]
pub enum SourceLoginKind {
    Header,
    Info,
}

/// 实现者自行协调内存与持久化，回调不得反向持有 VM 或 EngineContext。
pub trait SourceLoginStore: Send + Sync {
    fn get(&self, kind: SourceLoginKind, source_url: &str) -> Option<String>;
    fn put(&self, kind: SourceLoginKind, source_url: &str, value: &str);
    fn remove(&self, kind: SourceLoginKind, source_url: &str) -> Option<String>;
}

pub(crate) fn parse_key(key: &str) -> Option<(SourceLoginKind, &str)> {
    key.strip_prefix("loginHeader_")
        .map(|source| (SourceLoginKind::Header, source))
        .or_else(|| {
            key.strip_prefix("userInfo_")
                .map(|source| (SourceLoginKind::Info, source))
        })
}
