//! 服务器管理 API
//!
//! 提供 legado-server 的启动、停止和状态查询功能。
//! 使用独立的 tokio Runtime 运行 HTTP 服务器。
//!
//! Task #73（契约 §2.22.5 `setMcpPort`）：独立 MCP 服务端口管理——
//! 对齐原版 `McpService.kt` 独立前台服务（默认 1236，合法区间
//! 1024..65530，≤0 停止），与 Web 服务并存、独立启停。

use std::sync::OnceLock;

use tokio::runtime::Runtime;

use legado_core::{LegadoError, LegadoResult};

/// 服务器运行时（独立于 FFI 主 runtime）
static SERVER_RUNTIME: OnceLock<Runtime> = OnceLock::new();

/// 独立 MCP 服务默认端口（对齐原版 `AppConfig.mcpPort` 默认值）
pub const DEFAULT_MCP_PORT: u16 = 1236;

/// 独立 MCP 端口合法区间下限（对齐原版 NumberPicker）
const MCP_PORT_MIN: i32 = 1024;

/// 独立 MCP 端口合法区间上限（对齐原版 NumberPicker）
const MCP_PORT_MAX: i32 = 65530;

/// 配置持久化键（caches 表 `config:` 前缀，与既有 setConfig 同语义）
const MCP_PORT_CONFIG_KEY: &str = "mcpPort";

/// 获取或创建服务器专用 runtime
///
/// worker 线程栈 8MB（任务 #60 ②）：与 FFI 主 runtime 同步扩栈，
/// 防 spawn_blocking 上 regex-syntax 深递归击穿默认 2MB 栈。
fn get_server_runtime() -> LegadoResult<&'static Runtime> {
    if let Some(rt) = SERVER_RUNTIME.get() {
        return Ok(rt);
    }
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .worker_threads(
            std::thread::available_parallelism()
                .map(|n| n.get())
                .unwrap_or(2)
                .clamp(2, 8),
        )
        .thread_name("legado-server")
        .thread_stack_size(8 * 1024 * 1024)
        .build()
        .map_err(|e| LegadoError::Internal(format!("创建 server runtime 失败: {e}")))?;
    let _ = SERVER_RUNTIME.set(rt);
    SERVER_RUNTIME
        .get()
        .ok_or_else(|| LegadoError::Internal("server runtime 初始化失败".into()))
}

/// 启动 legado-server
///
/// 在独立 tokio runtime 中启动 HTTP 服务器。
/// 返回 "Server started on port {port}"。
///
/// DB 前置条件（§二.8 修复，审计 S28_DUAL_DB_AUDIT §五修法 A/B）：
/// Web 服务与主应用复用 `db_state` 全局连接池（单池）——不再硬编码相对
/// 路径 `"legado.db"`（Android 上会打不开或在 cwd 生成第二个空库），也
/// 不再二次建池。未初始化 / 取连接失败均**同步**返回 Err，不再 spawn 前
/// 返回「已启动」而把失败吞进任务内 eprintln。
///
/// 缺陷 A/B 修复（调研 IOS_WEB_SERVICE_ROOT_CAUSE_SURVEY_20261006 §一.3/4）：
/// - 绑定地址 `0.0.0.0`（全接口，LAN 可达）——对齐原版 `HttpServer.kt`
///   `NanoHTTPD(port)`（hostname=null → 绑全接口）与本文件 MCP 路径（F5）；
///   旧实现 `127.0.0.1` 使 PC 浏览器永远无法经 `http://<设备IP>:1122`
///   写源/看书（Android 侧此前靠 adb forward 掩蔽）。
/// - spawn **之前**同步 bind，端口占用等失败立即返回
///   `Internal("Web 服务端口 {port} 绑定失败: …")` 且不置运行态——
///   旧实现 spawn 后才 bind，失败仅任务内 eprintln，函数仍假成功返回 Ok。
///   成功后把已绑定 listener 交给 `serve_web`（对齐 mcp_start_internal）。
pub fn server_start(port: u16) -> LegadoResult<String> {
    let services = crate::engine_holder::services();
    let _control = services.web.control();
    let (running, current_port) = services.web.status();
    if running {
        return Ok(format!("Server already running on port {current_port}"));
    }

    // DB 必须已初始化（与 mcp_start_internal 同型守卫）
    if !crate::db_state::is_initialized() {
        return Err(LegadoError::Internal(
            "Web 服务启动失败：数据库未初始化，请先调用 db_open".into(),
        ));
    }

    // 传递主应用当前引擎；启动不借数据库连接，失败不置 running。
    let engine = crate::engine_holder::current()
        .map_err(|e| LegadoError::Internal(format!("Web 服务数据库连接失败: {e}")))?;

    let runtime = get_server_runtime()?;
    services.web.stop(runtime);

    // 缺陷 A/B 修复：spawn 前同步绑定 0.0.0.0（全接口，LAN 可达；对齐
    // 原版 HttpServer.kt 的 NanoHTTPD(port) 与本文件 MCP 路径 F5），
    // 失败即 Err、不置 running——不再 spawn 后 bind 造成「假成功」
    let listener = runtime
        .block_on(tokio::net::TcpListener::bind(("0.0.0.0", port)))
        .map_err(|e| LegadoError::Internal(format!("Web 服务端口 {port} 绑定失败: {e}")))?;

    let tasks = engine.tasks().clone();
    let state = services.state.clone();
    services
        .web
        .start(runtime, &tasks, port, move |scope| async move {
            if let Err(e) =
                legado_server::server::serve_web_scoped(listener, engine, scope, state).await
            {
                eprintln!("Server error: {e}");
            }
        })?;

    Ok(format!("Server started on port {port}"))
}

/// 停止服务器
///
/// 中止服务器任务并**等待任务真正结束**（listener 随之 drop、监听端口
/// 释放）后再返回（W-1，对齐 `mcp_stop_internal`）——否则紧随其后的
/// 同端口 `server_start` 会因 `AddrInUse` 同步失败（UI「关闭后马上重开」
/// 场景用户可见；审查报告 §W-1 探针实测确证）。返回 "Server stopped"。
pub fn server_stop() -> String {
    let services = crate::engine_holder::services();
    let _control = services.web.control();
    match get_server_runtime() {
        Ok(runtime) if services.web.stop(runtime) => "Server stopped".into(),
        _ => "Server not running".into(),
    }
}

/// 获取服务器状态，保留原 JSON 字段。
pub fn server_status() -> String {
    let status = read_server_status();
    serde_json::json!({ "running": status.running, "port": status.port }).to_string()
}

/// 状态快照与旧原生 JSON 适配器共用一次原子读取。
pub fn read_server_status() -> crate::file_dto::ServerStatusDto {
    let (running, port) = crate::engine_holder::services().web.status();
    crate::file_dto::ServerStatusDto { running, port }
}

// ─── 独立 MCP 服务（契约 §2.22.5 setMcpPort，Task #73） ───────

/// 设置独立 MCP 服务端口（启停状态机）
///
/// - `port <= 0`：停止独立 MCP 服务（Web 端口 /mcp/* 挂载不受影响），
///   并持久化该值；
/// - `port` 合法区间 `1024..=65530`（对齐原版 NumberPicker），
///   越界报 `Internal` 错误（可读消息）；
/// - 端口变更自动重启（先停旧再启新，abort 后等待旧监听器释放，
///   同端口重启不冲突，Task #76 M1）；端口绑定失败（如占用）
///   同步报 `Internal` 错误；
/// - F5：监听 `0.0.0.0`（LAN 可达，对齐原版 McpService）；启动前置要求
///   `config:jsSourceApiToken` 非空；独立端口 `/mcp/*` 校验 `X-Legado-Token`；
/// - 要求数据库已初始化（先 db_open），独立服务与主应用复用同一
///   全局连接池（P2 单池，与 Web 服务路径统一）；DB 未初始化返回
///   `Internal` 可读错误；
/// - 成功后持久化到 caches 表 `config:mcpPort`。
pub fn set_mcp_port(port: i32) -> LegadoResult<()> {
    // port <= 0：停止独立 MCP 服务
    if port <= 0 {
        {
            let services = crate::engine_holder::services();
            let _guard = services.mcp.control();
            if let Ok(runtime) = get_server_runtime() {
                services.mcp.stop(runtime);
            }
        }
        persist_mcp_port(port);
        return Ok(());
    }
    mcp_start_internal(port)?;
    persist_mcp_port(port);
    Ok(())
}

/// 启动独立 MCP 服务（内部实现，不持久化；Task #76 Min2：
/// restore_mcp_port 复用本函数绕过 persist，避免启动时重复写配置）
fn mcp_start_internal(port: i32) -> LegadoResult<()> {
    // 合法区间校验（对齐原版 1024..65530 NumberPicker 取值）
    if !(MCP_PORT_MIN..=MCP_PORT_MAX).contains(&port) {
        return Err(LegadoError::Internal(format!(
            "MCP 端口 {} 越界：合法区间为 {MCP_PORT_MIN}..{MCP_PORT_MAX}（对齐原版）",
            port
        )));
    }

    // 状态机全程互斥（Task #76 Med1）
    let services = crate::engine_holder::services();
    let _guard = services.mcp.control();

    // DB 必须已初始化：独立服务与主应用复用同一全局连接池（Task #76 C2；
    // P2 单池化后与 Web 服务路径统一，不再二次建池/重跑迁移）
    if !crate::db_state::is_initialized() {
        return Err(LegadoError::Internal(
            "独立 MCP 服务启动失败：数据库未初始化，请先调用 db_open".into(),
        ));
    }

    // F5：对齐原版 — jsSourceApiToken 非空才允许启动
    //
    // [2026-10-06 iOS 实测修复] 文案只改可读性（指向 App 内可见的条目名
    // 「Web 书源访问令牌」，路径对齐设置页：设置 → 高级 → 其他设置），
    // 校验语义与行为不变。
    let token = crate::api::config_api::get_config("jsSourceApiToken")
        .unwrap_or_default()
        .trim()
        .to_string();
    if token.is_empty() {
        return Err(LegadoError::Internal(
            "独立 MCP 服务启动失败：请先在「设置 → 高级 → 其他设置」配置「Web 书源访问令牌」（config:jsSourceApiToken）"
                .into(),
        ));
    }

    // 端口变更自动重启：先停旧服务（abort 后等待旧监听器释放）
    if let Ok(runtime) = get_server_runtime() {
        services.mcp.stop(runtime);
    }

    // 直接共享主应用引擎；数据库连接由具体操作短借，不随服务长期保留。
    let engine = crate::engine_holder::current()
        .map_err(|e| LegadoError::Internal(format!("独立 MCP 服务数据库连接失败: {e}")))?;

    let runtime = get_server_runtime()?;

    // F5：绑定 0.0.0.0（LAN 可达，对齐原版 McpService）
    let listener = runtime
        .block_on(tokio::net::TcpListener::bind(("0.0.0.0", port as u16)))
        .map_err(|e| LegadoError::Internal(format!("独立 MCP 服务端口 {} 绑定失败: {e}", port)))?;

    let tasks = engine.tasks().clone();
    let state = services.state.clone();
    services
        .mcp
        .start(runtime, &tasks, port as u16, move |scope| async move {
            if let Err(e) =
                legado_server::server::serve_mcp_scoped(listener, engine, token, scope, state).await
            {
                eprintln!("MCP server error: {e}");
            }
        })?;
    Ok(())
}

/// 独立 MCP 服务状态，保留原 JSON 字段。
pub fn mcp_status() -> String {
    let (running, port) = crate::engine_holder::services().mcp.status();
    serde_json::json!({ "running": running, "port": port }).to_string()
}

/// 持久化 MCP 端口配置（宽容失败：DB 未初始化/写入失败仅记日志）
fn persist_mcp_port(port: i32) {
    if !crate::db_state::is_initialized() {
        log::debug!("数据库未初始化，mcpPort 配置不持久化");
        return;
    }
    if let Err(e) = crate::api::config_api::set_config(MCP_PORT_CONFIG_KEY, &port.to_string()) {
        log::warn!("持久化 mcpPort 配置失败: {e}");
    }
}

/// 启动时恢复独立 MCP 服务（由 db_open 调用，尽力而为）
///
/// 读回 `config:mcpPort`：>0 时尝试启动独立服务（失败仅记日志，
/// 如端口已被占用）；≤0/缺省不启动。
pub fn restore_mcp_port() {
    if !crate::db_state::is_initialized() {
        return;
    }
    let value = match crate::api::config_api::get_config(MCP_PORT_CONFIG_KEY) {
        Ok(v) => v,
        Err(e) => {
            log::warn!("读取 mcpPort 配置失败: {e}");
            return;
        }
    };
    let value = value.trim();
    if value.is_empty() {
        return;
    }
    match value.parse::<i32>() {
        Ok(port) if port > 0 => {
            // Task #76 Min2：恢复路径复用内部启动函数绕过 persist，
            // 避免每次启动重复写 config:mcpPort
            if let Err(e) = mcp_start_internal(port) {
                log::warn!("启动时恢复独立 MCP 服务（端口 {port}）失败: {e}");
            }
        }
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_server_status_initial() {
        // 初始状态应为未运行
        let status = server_status();
        let json: serde_json::Value = serde_json::from_str(&status).unwrap();
        // 注意：如果其他测试先启动了服务器，这里可能为 true
        assert!(json.get("running").is_some());
        assert!(json.get("port").is_some());
    }

    #[test]
    fn test_server_stop_when_not_running() {
        // 未运行时停止应返回提示
        let result = server_stop();
        assert!(result == "Server not running" || result == "Server stopped");
    }

    // ─── 独立 MCP 服务（Task #73） ────────────────────────

    /// 串行锁：MCP 测试共享全局启停状态，需串行执行
    static MCP_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

    /// 取一个空闲端口（先绑 :0 再释放，随机端口策略避免 CI 冲突）
    fn pick_free_port() -> u16 {
        let listener = std::net::TcpListener::bind("0.0.0.0:0").unwrap();
        let port = listener.local_addr().unwrap().port();
        drop(listener);
        port
    }

    /// F5：测试启动前写入 jsSourceApiToken
    fn ensure_mcp_token() {
        crate::api::config_api::set_config("jsSourceApiToken", "test-mcp-token")
            .expect("写入测试 token");
    }

    /// 越界校验：合法区间 1024..65530（对齐原版）
    #[test]
    fn test_mcp_port_out_of_range() {
        let _g = MCP_TEST_LOCK.lock().unwrap();
        let low = set_mcp_port(1023);
        assert!(low.is_err(), "端口 1023 应报越界错误");
        let high = set_mcp_port(65531);
        assert!(high.is_err(), "端口 65531 应报越界错误");
        // 错误消息可读（含区间提示）
        let msg = format!("{}", high.unwrap_err());
        assert!(msg.contains("越界"));
    }

    /// port ≤ 0 停止独立服务（未运行时亦幂等成功）
    #[test]
    fn test_mcp_port_stop_semantics() {
        let _g = MCP_TEST_LOCK.lock().unwrap();
        assert!(set_mcp_port(0).is_ok());
        let status: serde_json::Value = serde_json::from_str(&mcp_status()).unwrap();
        assert_eq!(status["running"], false);
        assert!(set_mcp_port(-1).is_ok());
    }

    /// F5：token 未设置时拒绝启动
    #[test]
    fn test_mcp_requires_js_source_api_token() {
        let _g = MCP_TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        let _ = crate::api::config_api::set_config("jsSourceApiToken", "");
        let port = pick_free_port() as i32;
        let err = set_mcp_port(port).unwrap_err();
        assert!(
            err.to_string().contains("Token") || err.to_string().contains("token"),
            "应提示需配置 token: {err}"
        );
        // [2026-10-06] 文案须指向 App 内可见条目名，用户照做即可配置
        assert!(
            err.to_string().contains("Web 书源访问令牌"),
            "应提示 App 内配置入口「Web 书源访问令牌」: {err}"
        );
    }

    /// 启停状态机 + 端口变更自动重启 + 持久化（随机端口避免 CI 冲突）
    #[test]
    fn test_mcp_start_restart_stop_state_machine() {
        let _g = MCP_TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        ensure_mcp_token();

        let port1 = pick_free_port() as i32;
        set_mcp_port(port1).expect("首次启动应成功");
        let status: serde_json::Value = serde_json::from_str(&mcp_status()).unwrap();
        assert_eq!(status["running"], true);
        assert_eq!(status["port"].as_u64().unwrap(), port1 as u64);

        // 持久化：config:mcpPort 应为当前端口
        let persisted = crate::api::config_api::get_config("mcpPort").unwrap();
        assert_eq!(persisted, port1.to_string());

        // 端口变更自动重启（先停旧再启新）
        let port2 = pick_free_port() as i32;
        set_mcp_port(port2).expect("端口变更后重启应成功");
        let status: serde_json::Value = serde_json::from_str(&mcp_status()).unwrap();
        assert_eq!(status["running"], true);
        assert_eq!(status["port"].as_u64().unwrap(), port2 as u64);

        // port ≤ 0 停止
        set_mcp_port(0).unwrap();
        let status: serde_json::Value = serde_json::from_str(&mcp_status()).unwrap();
        assert_eq!(status["running"], false);
    }

    /// 同端口重启循环（Task #76 M1）：set→stop→set 同端口成功，
    /// abort 后等待旧监听器释放，不再报 AddrInUse
    #[test]
    fn test_mcp_same_port_restart_cycle() {
        let _g = MCP_TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        ensure_mcp_token();

        let port = pick_free_port() as i32;
        set_mcp_port(port).expect("首次启动应成功");
        set_mcp_port(0).expect("停止应成功");
        set_mcp_port(port).expect("同端口重启应成功（旧监听器已释放）");
        let status: serde_json::Value = serde_json::from_str(&mcp_status()).unwrap();
        assert_eq!(status["running"], true);
        assert_eq!(status["port"].as_u64().unwrap(), port as u64);
        set_mcp_port(0).unwrap();
    }

    /// 端口被占用：绑定失败报 Internal（可读消息）
    #[test]
    fn test_mcp_port_bind_conflict() {
        let _g = MCP_TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        ensure_mcp_token();
        // 占用 0.0.0.0 端口（与 set_mcp_port F5 绑定同地址族）
        let blocker = std::net::TcpListener::bind("0.0.0.0:0").unwrap();
        let port = blocker.local_addr().unwrap().port() as i32;

        let result = set_mcp_port(port);
        assert!(result.is_err(), "端口被占用时应报绑定失败");
        let msg = format!("{}", result.unwrap_err());
        assert!(msg.contains("绑定失败"));

        drop(blocker);
    }
}
