//! RAR 停用边界必须覆盖默认沙箱、裸函数和通用解压别名。
#![cfg(feature = "quickjs")]

use legado_js::{JsEngine, QuickJsEngine, SandboxConfig};

fn rejected(engine: &QuickJsEngine, script: &str) {
    let error = engine.eval(script).expect_err("不安全的 RAR 入口必须抛错");
    assert!(error.to_string().contains("JS RAR 功能暂不支持"), "{error}");
}

#[test]
fn rar_rejected_before_network_or_file_access_in_both_sandboxes() {
    for config in [SandboxConfig::default(), SandboxConfig::permissive()] {
        let engine = QuickJsEngine::new(config).unwrap();
        for prefix in ["java.", ""] {
            rejected(
                &engine,
                &format!("{prefix}unrarFile('does-not-exist.rar', 'must-not-create')"),
            );
            rejected(
                &engine,
                &format!("{prefix}getRarStringContent('http://127.0.0.1:0/a.rar', '../secret')"),
            );
        }
        assert_eq!(engine.eval("1 + 1").unwrap(), "2");
    }
}

#[test]
fn generic_archive_aliases_cannot_bypass_rar_rejection() {
    let dir = std::env::temp_dir().join(format!("legado_rar_security_{}", uuid::Uuid::new_v4()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("disguised.zip");
    std::fs::write(&path, b"Rar!\x1a\x07\x01\x00").unwrap();
    let arg = serde_json::to_string(path.to_str().unwrap()).unwrap();
    let engine = QuickJsEngine::new(SandboxConfig::default()).unwrap();
    for name in [
        "java.unArchiveFile",
        "java.unzipFile",
        "unArchiveFile",
        "unzipFile",
    ] {
        rejected(&engine, &format!("{name}({arg})"));
    }
    assert!(!dir.join("disguised").exists());
    std::fs::remove_dir_all(dir).unwrap();
}
