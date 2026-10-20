//! VM 仅持此数据能力，不持执行缓存或根引擎。
use std::sync::Arc;
#[derive(Default)]
pub struct JsHostResources {
    pub webview: Arc<legado_core::webview_channel::WebViewManager>,
    pub config: Arc<crate::host_api::config_api::HostConfiguration>,
    pub cache: Arc<crate::host_api::cache_store::CacheStore>,
    pub concurrency: Arc<crate::host_api::concurrency_api::ConcurrencyState>,
}

#[cfg(all(test, feature = "quickjs"))]
mod tests {
    use crate::{JsEngine, JsResources, SandboxConfig};
    use std::sync::Arc;
    #[test]
    fn cached_vm_reads_own_live_configuration_and_device_identity() {
        let first = JsResources::default();
        let other = JsResources::default();
        let one = first.create_engine(SandboxConfig::default()).unwrap();
        let two = other.create_engine(SandboxConfig::default()).unwrap();
        assert_eq!(one.eval("getThemeMode()").unwrap(), "light");
        first.host_resources().config.set_injected_theme_mode("2");
        first
            .host_resources()
            .config
            .set_injected_read_book_config(r#"{"name":"first"}"#);
        first
            .host_resources()
            .config
            .device
            .set_device_id("first-device");
        other
            .host_resources()
            .config
            .device
            .set_device_id("other-device");
        assert_eq!(one.eval("getThemeMode()").unwrap(), "dark");
        assert_eq!(two.eval("getThemeMode()").unwrap(), "light");
        assert_eq!(one.eval("getReadBookConfigMap().name").unwrap(), "first");
        assert_ne!(two.eval("getReadBookConfigMap().name").unwrap(), "first");
        assert_eq!(one.eval("androidId()").unwrap(), "first-device");
        assert_eq!(two.eval("androidId()").unwrap(), "other-device");
        first.host_resources().config.device.set_device_id("");
        assert_eq!(one.eval("androidId()").unwrap(), "first-device");
    }

    #[test]
    fn vm_and_flow_share_own_cache_and_counters_but_other_engines_do_not() {
        let first = Arc::new(JsResources::default());
        let weak = Arc::downgrade(&first);
        let one = first.create_engine(SandboxConfig::default()).unwrap();
        let two_resources = JsResources::default();
        let two = two_resources
            .create_engine(SandboxConfig::default())
            .unwrap();
        assert_eq!(
            one.eval("cache.putMemory('same','one');cache.put('disk','first',0);java.tick('same')")
                .unwrap(),
            "1"
        );
        let other: serde_json::Value = serde_json::from_str(&two.eval("JSON.stringify([cache.getFromMemory('same'),cache.get('disk',true),java.tick('same')])").unwrap()).unwrap();
        assert_eq!(other, serde_json::json!([null, null, 1]));
        let flow = first.for_source("search", "same", "query");
        let continuation = flow.create_engine(SandboxConfig::default()).unwrap();
        let same: serde_json::Value = serde_json::from_str(&continuation.eval("JSON.stringify([cache.getFromMemory('same'),cache.get('disk',true),java.tick('same')])").unwrap()).unwrap();
        assert_eq!(same, serde_json::json!(["one", "first", 2]));
        let path = first.host_resources().cache.disk_dir().unwrap();
        let other_path = two_resources.host_resources().cache.disk_dir().unwrap();
        assert_ne!(path, other_path);
        drop(flow);
        drop(first);
        assert!(weak.upgrade().is_none());
        assert!(path.exists());
        drop(one);
        drop(continuation);
        assert!(!path.exists());
        assert!(other_path.exists());
    }

    #[test]
    fn vm_cache_also_checks_host_data_identity_for_same_variable_owner() {
        let first = JsResources::default();
        let other = JsResources::default().with_variable_scope(first.variables().unscoped());
        let cache = crate::engine_cache::EngineCache::default();
        let one = cache
            .get_or_create_with_resources("same", None, None, None, &first)
            .unwrap();
        one.engine
            .lock()
            .unwrap()
            .eval("cache.putMemory('key','first')")
            .unwrap();
        let two = cache
            .get_or_create_with_resources("same", None, None, None, &other)
            .unwrap();
        assert!(!Arc::ptr_eq(&one.engine, &two.engine));
        assert_eq!(
            two.engine
                .lock()
                .unwrap()
                .eval("cache.getFromMemory('key')===null")
                .unwrap(),
            "true"
        );
    }
}
