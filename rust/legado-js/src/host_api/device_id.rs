//! 设备身份归属宿主数据能力，不使用进程级可替换槽。
use std::sync::RwLock;
#[derive(Default)]
pub struct DeviceIdentity {
    value: RwLock<Option<String>>,
}
impl DeviceIdentity {
    pub fn set_device_id(&self, id: &str) {
        let id = id.trim();
        if !id.is_empty() && id != "null" {
            *self.value.write().unwrap_or_else(|p| p.into_inner()) = Some(id.into());
        }
    }
    pub fn device_id(&self) -> Option<String> {
        self.value.read().unwrap_or_else(|p| p.into_inner()).clone()
    }
}
#[cfg(test)]
fn test_identity() -> &'static DeviceIdentity {
    static IDENTITY: std::sync::OnceLock<DeviceIdentity> = std::sync::OnceLock::new();
    IDENTITY.get_or_init(Default::default)
}
#[cfg(test)]
fn set_device_id(id: &str) {
    test_identity().set_device_id(id);
}
#[cfg(test)]
fn device_id() -> Option<String> {
    test_identity().device_id()
}
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_set_and_get_device_id() {
        set_device_id("70f79699ca032aeb");
        assert_eq!(device_id().as_deref(), Some("70f79699ca032aeb"));
    }

    #[test]
    fn test_ignores_empty_device_id() {
        set_device_id("");
        set_device_id("null");
        // 空值不覆盖既有注入；首次无注入时保持 None
        assert!(device_id().as_deref() != Some(""));
    }
}
