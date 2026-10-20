//! 规则订阅存储与更新准备，供FFI和Web宿主共同使用。
use legado_core::{LegadoError, LegadoResult};
use legado_db::{Database, RuleSubRecord, RuleSubRepository};
use legado_net::{RuleSubscription, custom_hosts::CustomHosts, merge_subscription, should_update};
use serde::Serialize;
use std::sync::Arc;

/// 在宿主的数据库闭包内短借连接；不可持有此服务等待网络。
pub struct RuleSubscriptionService<'a> {
    repo: RuleSubRepository<'a>,
}
impl<'a> RuleSubscriptionService<'a> {
    pub fn new(db: &'a Database) -> Self {
        Self {
            repo: RuleSubRepository::new(db.connection()),
        }
    }
    pub fn list_subs(&self) -> LegadoResult<Vec<RuleSubRecord>> {
        self.repo.find_all()
    }
    pub fn enabled_subs(&self) -> LegadoResult<Vec<RuleSubRecord>> {
        self.repo.get_enabled_subs()
    }
    pub fn find_by_url(&self, url: &str) -> LegadoResult<Option<RuleSubRecord>> {
        self.repo.find_by_url(url)
    }
    pub fn require_sub(&self, id: i64) -> LegadoResult<RuleSubRecord> {
        self.repo
            .find_by_id(id)?
            .ok_or_else(|| LegadoError::Database(format!("未找到 id={id} 的订阅记录")))
    }
    pub fn save_sub(&self, record: &RuleSubRecord) -> LegadoResult<bool> {
        if record.id > 0 && self.repo.find_by_id(record.id)?.is_some() {
            self.repo.update(record)?;
        } else {
            self.repo.insert(record)?;
        }
        Ok(true)
    }
    pub fn delete_sub(&self, id: i64) -> LegadoResult<bool> {
        let exists = self.repo.find_by_id(id)?.is_some();
        if exists {
            self.repo.delete(id)?;
        }
        Ok(exists)
    }
    pub fn set_sub_enabled(&self, id: i64, enabled: bool) -> LegadoResult<bool> {
        let exists = self.repo.find_by_id(id)?.is_some();
        if exists {
            self.repo.set_enabled(id, enabled)?;
        }
        Ok(exists)
    }
    pub fn update_sub_order(&self, ids: &[i64]) -> LegadoResult<bool> {
        self.repo.update_order(ids)?;
        Ok(true)
    }
    /// 返回真实回写错误，是否忽略由宿主按原策略决定。
    pub fn update_version(&self, update: &VersionUpdate) -> LegadoResult<()> {
        self.repo
            .update_version(update.id, &update.version, update.timestamp)
    }
}

/// 检查更新结果（JSON 序列化后返回 Dart 层）
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CheckUpdateResponse {
    /// 订阅 ID
    pub id: i64,
    /// 订阅 URL
    pub url: String,
    /// 订阅名称
    pub name: String,
    /// 是否到达更新间隔（should_update 判定）
    pub due_for_update: bool,
    /// 远程是否有内容更新
    pub has_update: bool,
    /// 远程版本号（若能提取）
    pub remote_version: Option<String>,
    /// 错误信息
    pub error: Option<String>,
}

/// 应用更新结果（JSON 序列化后返回 Dart 层）
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ApplyUpdateResponse {
    /// 订阅 ID
    pub id: i64,
    /// 订阅 URL
    pub url: String,
    /// 是否成功
    pub success: bool,
    /// 新增条目数
    pub items_added: usize,
    /// 更新条目数
    pub items_updated: usize,
    /// 移除条目数
    pub items_removed: usize,
    /// 合并后的条目总数
    pub total_items: usize,
    /// 错误信息
    pub error: Option<String>,
}

/// 当前时间戳（毫秒）
fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

/// 从订阅 JSON 内容中提取版本信息（与 server 端 extract_version 语义一致）
fn extract_version(json_str: &str) -> Option<String> {
    if let Ok(obj) = serde_json::from_str::<serde_json::Value>(json_str)
        && let Some(v) = obj.get("version").and_then(|v| v.as_str())
    {
        return Some(v.to_string());
    }
    None
}

/// 合并成功后需要回写的元数据，不包含待导入的实体写入操作。
#[derive(Debug, Clone)]
pub struct VersionUpdate {
    pub id: i64,
    pub version: String,
    pub timestamp: i64,
}

/// 区分拉取与合并失败，保留Web两类失败响应的原有形状。
#[derive(Debug)]
pub enum PreparedUpdate {
    FetchFailed(String),
    MergeFailed(String),
    Ready {
        update: VersionUpdate,
        merged: legado_net::MergeResult,
    },
}
impl PreparedUpdate {
    pub fn version_update(&self) -> Option<&VersionUpdate> {
        match self {
            Self::Ready { update, .. } => Some(update),
            _ => None,
        }
    }
    pub fn into_response(self, sub: &RuleSubRecord) -> ApplyUpdateResponse {
        let mut response = ApplyUpdateResponse {
            id: sub.id,
            url: sub.url.clone(),
            success: false,
            items_added: 0,
            items_updated: 0,
            items_removed: 0,
            total_items: 0,
            error: None,
        };
        match self {
            Self::FetchFailed(error) | Self::MergeFailed(error) => response.error = Some(error),
            Self::Ready { merged, .. } => {
                response.success = true;
                response.items_added = merged.added;
                response.items_updated = merged.updated;
                response.items_removed = merged.removed;
                response.total_items =
                    serde_json::from_str::<Vec<serde_json::Value>>(&merged.merged_json)
                        .map(|v| v.len())
                        .unwrap_or(0);
            }
        }
        response
    }
}

async fn fetch(sub: &RuleSubRecord, hosts: Arc<CustomHosts>) -> Result<String, String> {
    let subscription = RuleSubscription {
        url: sub.url.clone(),
        name: sub.name.clone(),
        sub_type: sub.sub_type.clone(),
    };
    legado_net::rule_update_client::fetch_subscription_with_hosts(&subscription, hosts).await
}

/// 两个宿主共享远程检查；Web不计算或返回更新间隔。
#[derive(Debug)]
pub struct RemoteCheckResult {
    pub has_update: bool,
    pub remote_version: Option<String>,
    pub error: Option<String>,
}
pub async fn check_update(sub: &RuleSubRecord, hosts: Arc<CustomHosts>) -> RemoteCheckResult {
    let mut response = RemoteCheckResult {
        has_update: false,
        remote_version: None,
        error: None,
    };
    match fetch(sub, hosts).await {
        Ok(remote_json) => {
            response.remote_version = extract_version(&remote_json);
            response.has_update = match &response.remote_version {
                Some(version) => version != &sub.version,
                None => !remote_json.is_empty(),
            };
        }
        Err(error) => response.error = Some(error),
    }
    response
}

/// FFI原有间隔判定仅供显示，即使尚未到期也实际检查。
pub async fn check_update_with_interval(
    sub: &RuleSubRecord,
    hosts: Arc<CustomHosts>,
) -> CheckUpdateResponse {
    let due_for_update = should_update(sub.last_update, sub.update_interval, now_millis());
    let remote = check_update(sub, hosts).await;
    CheckUpdateResponse {
        id: sub.id,
        url: sub.url.clone(),
        name: sub.name.clone(),
        due_for_update,
        has_update: remote.has_update,
        remote_version: remote.remote_version,
        error: remote.error,
    }
}

/// 只准备原合并统计与元数据；不声称已经导入各类实体表。
pub async fn prepare_update(sub: &RuleSubRecord, hosts: Arc<CustomHosts>) -> PreparedUpdate {
    let remote_json = match fetch(sub, hosts).await {
        Ok(content) => content,
        Err(error) => return PreparedUpdate::FetchFailed(format!("拉取订阅失败: {error}")),
    };
    match merge_subscription("[]", &remote_json, &sub.sub_type) {
        Ok(merged) => PreparedUpdate::Ready {
            update: VersionUpdate {
                id: sub.id,
                version: extract_version(&remote_json).unwrap_or_default(),
                timestamp: now_millis(),
            },
            merged,
        },
        Err(error) => PreparedUpdate::MergeFailed(error),
    }
}

#[cfg(test)]
mod tests;
