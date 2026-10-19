//! 自动下载缓存只属于当前资源；不改变调用方显式选择的文件路径。

use std::path::PathBuf;
use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, Ordering};

#[derive(Default)]
pub(crate) struct ResourceFiles {
    directory: Mutex<Option<PathBuf>>,
}

impl ResourceFiles {
    /// 完整写入临时文件后再发布；失败不留下可被下次命中的半份目标文件。
    #[cfg(any(feature = "quickjs", test))]
    pub(crate) fn publish(&self, name: &str, bytes: &[u8]) -> Result<PathBuf, String> {
        let directory = self.directory()?;
        let target = directory.join(name);
        let temporary = directory.join(format!("{name}.part"));
        let result =
            std::fs::write(&temporary, bytes).and_then(|()| std::fs::rename(&temporary, &target));
        if let Err(error) = result {
            let _ = std::fs::remove_file(temporary);
            return Err(format!("发布资源缓存失败: {error}"));
        }
        Ok(target)
    }

    /// 懒创建私有目录；编号只避免路径碰撞，不存放引擎或会话状态。
    pub(crate) fn directory(&self) -> Result<PathBuf, String> {
        static NEXT: AtomicU64 = AtomicU64::new(0);
        let mut directory = self.directory.lock().unwrap_or_else(|p| p.into_inner());
        if let Some(path) = directory.as_ref() {
            return Ok(path.clone());
        }
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let root = std::env::temp_dir().join("legado_js_cache");
        std::fs::create_dir_all(&root)
            .map_err(|error| format!("创建资源缓存根目录失败: {error}"))?;
        for _ in 0..32 {
            let path = root.join(format!(
                "legado_js_resource_{}_{}_{}",
                std::process::id(),
                timestamp,
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            match std::fs::create_dir(&path) {
                Ok(()) => {
                    *directory = Some(path.clone());
                    return Ok(path);
                }
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(error) => return Err(format!("创建资源缓存目录失败: {error}")),
            }
        }
        Err("无法分配独立资源缓存目录".into())
    }
}

impl Drop for ResourceFiles {
    fn drop(&mut self) {
        // 只删除本对象成功创建并持有的目录，不接受外部目录配置。
        if let Some(path) = self
            .directory
            .get_mut()
            .unwrap_or_else(|p| p.into_inner())
            .take()
        {
            let _ = std::fs::remove_dir_all(path);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn directories_are_independent_and_released_with_their_owner() {
        let one = ResourceFiles::default();
        let two = ResourceFiles::default();
        let first = one.directory().unwrap();
        let second = two.directory().unwrap();
        assert_ne!(first, second);
        assert_eq!(one.directory().unwrap(), first);
        std::fs::write(first.join("fixture"), b"one").unwrap();
        drop(one);
        assert!(!first.exists());
        assert!(second.exists());
        drop(two);
        assert!(!second.exists());
    }

    #[test]
    fn failed_publication_removes_partial_file_and_success_preserves_bytes() {
        let files = ResourceFiles::default();
        let directory = files.directory().unwrap();
        std::fs::create_dir(directory.join("blocked")).unwrap();
        assert!(files.publish("blocked", &[0xff, 0x80, 0x00]).is_err());
        assert!(!directory.join("blocked.part").exists());
        let path = files.publish("complete", &[0xff, 0x80, 0x00]).unwrap();
        assert_eq!(std::fs::read(path).unwrap(), [0xff, 0x80, 0x00]);
        assert!(!directory.join("complete.part").exists());
    }
}
