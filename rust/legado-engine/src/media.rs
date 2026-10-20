//! 宿主媒体目录及音频下载取消状态，不持有引擎或运行时。
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, RwLock};

pub struct MediaState {
    tts_directory: RwLock<PathBuf>,
    audio_directory: Mutex<Option<PathBuf>>,
    image_directory: Mutex<Option<PathBuf>>,
    generation: AtomicU64,
    active: AtomicUsize,
    publish: Mutex<()>,
    cloud: Mutex<Option<Arc<legado_fetcher::cloud_tts::CloudTtsHttpTransport>>>,
    pub tts_writes: legado_core::write_coordinator::KeyedWriteCoordinator,
}

impl Default for MediaState {
    fn default() -> Self {
        Self {
            tts_directory: RwLock::new(std::env::temp_dir().join("legado_tts_cache")),
            audio_directory: Mutex::new(None),
            image_directory: Mutex::new(None),
            generation: AtomicU64::new(0),
            active: AtomicUsize::new(0),
            publish: Mutex::new(()),
            cloud: Mutex::new(None),
            tts_writes: Default::default(),
        }
    }
}

impl MediaState {
    /// 云请求客户端独立于书源 Cookie/登录客户端，但由本实例复用。
    pub fn cloud_transport(
        &self,
        hosts: Arc<legado_net::custom_hosts::CustomHosts>,
    ) -> legado_core::LegadoResult<Arc<legado_fetcher::cloud_tts::CloudTtsHttpTransport>> {
        let mut slot = self.cloud.lock().unwrap_or_else(|p| p.into_inner());
        if let Some(transport) = slot.as_ref() {
            return Ok(transport.clone());
        }
        let transport =
            Arc::new(legado_fetcher::cloud_tts::CloudTtsHttpTransport::with_custom_hosts(hosts)?);
        *slot = Some(transport.clone());
        Ok(transport)
    }

    pub fn reset_cloud_transport(&self) {
        *self.cloud.lock().unwrap_or_else(|p| p.into_inner()) = None;
    }

    pub fn tts_directory(&self) -> PathBuf {
        self.tts_directory
            .read()
            .unwrap_or_else(|p| p.into_inner())
            .clone()
    }
    pub fn set_tts_directory(&self, directory: PathBuf) {
        *self
            .tts_directory
            .write()
            .unwrap_or_else(|p| p.into_inner()) = directory;
    }
    pub fn image_directory(&self) -> Option<PathBuf> {
        self.image_directory
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .clone()
    }
    pub fn set_image_directory(&self, directory: Option<PathBuf>) {
        *self
            .image_directory
            .lock()
            .unwrap_or_else(|p| p.into_inner()) = directory;
    }

    pub fn audio_directory(&self) -> Option<PathBuf> {
        self.audio_directory
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .clone()
    }
    pub fn set_audio_directory(&self, directory: Option<PathBuf>) {
        *self
            .audio_directory
            .lock()
            .unwrap_or_else(|p| p.into_inner()) = directory;
    }
    pub fn active_audio(&self) -> usize {
        self.active.load(Ordering::Acquire)
    }

    pub fn begin_audio(self: &Arc<Self>) -> AudioTransfer {
        let _publish = self.publish.lock().unwrap_or_else(|p| p.into_inner());
        self.active.fetch_add(1, Ordering::AcqRel);
        AudioTransfer {
            owner: self.clone(),
            generation: self.generation.load(Ordering::Acquire),
        }
    }

    /// 只取消已经登记的下载；新下载使用新快照，不能被旧任务收尾覆盖。
    pub fn cancel_audio(&self) -> bool {
        let _publish = self.publish.lock().unwrap_or_else(|p| p.into_inner());
        if self.active_audio() == 0 {
            return false;
        }
        self.generation.fetch_add(1, Ordering::AcqRel);
        true
    }
}

pub struct AudioTransfer {
    owner: Arc<MediaState>,
    generation: u64,
}
impl AudioTransfer {
    pub fn is_cancelled(&self) -> bool {
        self.generation != self.owner.generation.load(Ordering::Acquire)
    }
    pub fn with_active<T>(&self, commit: impl FnOnce() -> T) -> Option<T> {
        let _publish = self.owner.publish.lock().unwrap_or_else(|p| p.into_inner());
        if self.is_cancelled() {
            None
        } else {
            Some(commit())
        }
    }
}
impl Drop for AudioTransfer {
    fn drop(&mut self) {
        self.owner.active.fetch_sub(1, Ordering::AcqRel);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn independent_media_paths_and_cancellation_do_not_cross_instances() {
        let first = Arc::new(MediaState::default());
        let second = Arc::new(MediaState::default());
        first.set_tts_directory("first-tts".into());
        first.set_audio_directory(Some("first-audio".into()));
        assert_ne!(first.tts_directory(), second.tts_directory());
        assert!(second.audio_directory().is_none());
        let old = first.begin_audio();
        let other = second.begin_audio();
        assert!(first.cancel_audio());
        assert!(old.is_cancelled());
        assert!(!other.is_cancelled());
        let next = first.begin_audio();
        assert!(!next.is_cancelled());
        assert!(old.with_active(|| panic!("旧下载不得提交")).is_none());
        assert_eq!(next.with_active(|| 42), Some(42));
        drop(old);
        assert_eq!(first.active_audio(), 1);
        drop(next);
        assert!(!first.cancel_audio());
        assert_eq!(second.active_audio(), 1);
    }
}
