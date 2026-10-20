//! 书源 V1 登录动作执行（对齐 Kotlin BaseSource.login()）
//!
//! V1 登录：书源 loginUrl 为 JS 脚本（定义 `login()` 函数），loginUi 为
//! 表单 JSON（按钮 action 如 `login()`）。原版 `BaseSource.login()` 在完整
//! 书源上下文（jsLib + source/cookie/java 绑定 + setup）执行
//! `loginJs + login.apply(this)`；书山聚合等源在 login() 内经
//! `java.ajax(/login)` 取 api_key 并 `source.putLoginHeader` 落库。
//!
//! Engine服务复用共享解析器
//! 注入 sanitize 后 jsLib + setup（含 header 规则 → 实例 Cookie 罐/来源请求头），
//! JS 登录键直接访问本实例登录服务，不再经全局变量表事后复制。
//! 后续请求消费同一登录缓存。

use legado_core::{LegadoResult, models::BookSource};

pub fn eval_login_v1(source_json: &str, action: &str) -> LegadoResult<String> {
    let source: BookSource = serde_json::from_str(source_json)?;
    crate::source_action_host::service().eval_login_v1(&source, action)
}
