//! 本机协议 fixture 和可控异步传输，不需要真实 API Key 或云账号。
use super::*;
use legado_core::cloud_tts_openai::OpenAiCloudTtsProvider;
use std::sync::atomic::{AtomicUsize, Ordering};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
    sync::Notify,
};
struct Directory(PathBuf);
impl Directory {
    fn new() -> Self {
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        let path = std::env::temp_dir().join(format!(
            "legado_cloud_fixture_{}_{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir_all(&path).unwrap();
        Self(path)
    }
}
impl Drop for Directory {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}
fn engine() -> CloudTtsEngine {
    CloudTtsEngine {
        id: "cloud-fixture".into(),
        api_key: "local-fixture-key".into(),
        ..Default::default()
    }
}
fn request() -> CloudTtsSynthesisRequest {
    CloudTtsSynthesisRequest {
        text: "中文\"引号\"😀\n换行".into(),
        voice_id: "coral".into(),
        format: "wav".into(),
        ..Default::default()
    }
}
fn wav() -> Vec<u8> {
    legado_core::cloud_tts::pcm16_mono_to_wav(&[0, 1, 0, 2], 24000).unwrap()
}
struct Transport {
    calls: AtomicUsize,
    entered: Notify,
    release: Notify,
    blocking: bool,
    status: u16,
    mime: String,
    bytes: Vec<u8>,
}
impl Transport {
    fn new() -> Self {
        Self {
            calls: AtomicUsize::new(0),
            entered: Notify::new(),
            release: Notify::new(),
            blocking: false,
            status: 200,
            mime: "audio/wav".into(),
            bytes: wav(),
        }
    }
}
impl CloudTtsTransport for Transport {
    fn send<'a>(
        &'a self,
        _request: &'a PreparedCloudSpeech,
    ) -> BoxFuture<'a, LegadoResult<CloudTtsResponse>> {
        Box::pin(async {
            self.calls.fetch_add(1, Ordering::SeqCst);
            self.entered.notify_one();
            if self.blocking {
                self.release.notified().await;
            }
            Ok(CloudTtsResponse {
                status: self.status,
                content_type: self.mime.clone(),
                bytes: self.bytes.clone(),
            })
        })
    }
}
#[tokio::test]
async fn real_post_headers_unicode_and_audio_file() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let server = tokio::spawn(async move {
        let (mut stream, _) = listener.accept().await.unwrap();
        let mut data = vec![];
        let head_end = loop {
            let mut buf = [0u8; 2048];
            let n = stream.read(&mut buf).await.unwrap();
            assert!(n > 0);
            data.extend_from_slice(&buf[..n]);
            if let Some(i) = data.windows(4).position(|w| w == b"\r\n\r\n") {
                break i + 4;
            }
        };
        let head = String::from_utf8(data[..head_end].to_vec()).unwrap();
        let length = head
            .lines()
            .find_map(|l| {
                let (k, v) = l.split_once(':')?;
                k.eq_ignore_ascii_case("content-length")
                    .then(|| v.trim().parse::<usize>().unwrap())
            })
            .unwrap();
        while data.len() < head_end + length {
            let mut buf = [0u8; 2048];
            let n = stream.read(&mut buf).await.unwrap();
            assert!(n > 0);
            data.extend_from_slice(&buf[..n]);
        }
        let body: serde_json::Value =
            serde_json::from_slice(&data[head_end..head_end + length]).unwrap();
        let audio = wav();
        let header = format!(
            "HTTP/1.1 200 OK\r\nContent-Type: audio/wav\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            audio.len()
        );
        stream.write_all(header.as_bytes()).await.unwrap();
        stream.write_all(&audio).await.unwrap();
        (head, body)
    });
    let mut e = engine();
    e.base_url = format!("http://{address}/v1");
    let directory = Directory::new();
    let transport = CloudTtsHttpTransport::with_proxy_discovery(false).unwrap();
    let audio = synthesize_cloud_tts(
        &OpenAiCloudTtsProvider,
        &transport,
        &e,
        &request(),
        &directory.0,
        &TtsCancellation::default(),
    )
    .await
    .unwrap();
    let (head, body) = server.await.unwrap();
    assert!(head.starts_with("POST /v1/audio/speech HTTP/1.1"));
    assert!(
        head.to_lowercase()
            .contains("authorization: bearer local-fixture-key")
    );
    assert!(
        head.to_lowercase()
            .contains("content-type: application/json")
    );
    assert!(!head.to_lowercase().contains("cookie:"));
    assert_eq!(body["input"], request().text);
    assert_eq!(body["voice"], "coral");
    assert_eq!(std::fs::read(&audio.audio_path).unwrap(), wav());
    assert!(!audio.from_cache);
}
#[tokio::test]
async fn cached_audio_pinned_and_actual_inputs_define_identity() {
    let directory = Directory::new();
    let transport = Transport::new();
    let e = engine();
    let r = request();
    let cancel = TtsCancellation::default();
    let first = synthesize_cloud_tts(
        &OpenAiCloudTtsProvider,
        &transport,
        &e,
        &r,
        &directory.0,
        &cancel,
    )
    .await
    .unwrap();
    let mut volume_only = r.clone();
    volume_only.volume = 0.3;
    volume_only.pitch = 1.7;
    let cached = synthesize_cloud_tts(
        &OpenAiCloudTtsProvider,
        &transport,
        &e,
        &volume_only,
        &directory.0,
        &cancel,
    )
    .await
    .unwrap();
    assert!(cached.from_cache);
    assert_eq!(first.audio_path, cached.audio_path);
    assert_eq!(transport.calls.load(Ordering::SeqCst), 1);
    let cache = TtsCache::open(&directory.0).unwrap();
    assert_eq!(
        cache.clear(None, None, None, None).unwrap().skipped_files,
        1
    );
    let mut changed = r.clone();
    changed.style = "高兴".into();
    let other = synthesize_cloud_tts(
        &OpenAiCloudTtsProvider,
        &transport,
        &e,
        &changed,
        &directory.0,
        &cancel,
    )
    .await
    .unwrap();
    assert_ne!(other.audio_path, first.audio_path);
    drop(other);
    let mut changed_engine = e.clone();
    changed_engine.api_key = "another-fixture-key".into();
    let other = synthesize_cloud_tts(
        &OpenAiCloudTtsProvider,
        &transport,
        &changed_engine,
        &r,
        &directory.0,
        &cancel,
    )
    .await
    .unwrap();
    assert_ne!(other.audio_path, first.audio_path);
    drop(other);
    changed_engine = e.clone();
    changed_engine.enabled = false;
    assert!(
        synthesize_cloud_tts(
            &OpenAiCloudTtsProvider,
            &transport,
            &changed_engine,
            &r,
            &directory.0,
            &cancel
        )
        .await
        .is_err()
    );
    changed_engine = e.clone();
    changed_engine.api_key.clear();
    assert!(
        synthesize_cloud_tts(
            &OpenAiCloudTtsProvider,
            &transport,
            &changed_engine,
            &r,
            &directory.0,
            &cancel
        )
        .await
        .is_err()
    );
    drop(first);
    drop(cached);
    let clear = cache.clear(None, None, None, None).unwrap();
    assert_eq!(clear.removed_files, 3);
    assert!(cache.list().unwrap().is_empty());
}
#[tokio::test]
async fn duplicate_input_one_request_and_waiting_cancel_returns_promptly() {
    let directory = Directory::new();
    let transport = Arc::new(Transport {
        blocking: true,
        ..Transport::new()
    });
    let e = engine();
    let r = request();
    let dir = directory.0.clone();
    let t = transport.clone();
    let e1 = e.clone();
    let r1 = r.clone();
    let first = tokio::spawn(async move {
        synthesize_cloud_tts(
            &OpenAiCloudTtsProvider,
            t.as_ref(),
            &e1,
            &r1,
            &dir,
            &TtsCancellation::default(),
        )
        .await
    });
    transport.entered.notified().await;
    let cancel = TtsCancellation::default();
    let c = cancel.clone();
    let dir = directory.0.clone();
    let t = transport.clone();
    let e2 = e.clone();
    let r2 = r.clone();
    let waiting = tokio::spawn(async move {
        synthesize_cloud_tts(&OpenAiCloudTtsProvider, t.as_ref(), &e2, &r2, &dir, &c).await
    });
    tokio::task::yield_now().await;
    cancel.cancel();
    let error = tokio::time::timeout(Duration::from_secs(1), waiting)
        .await
        .unwrap()
        .unwrap()
        .err()
        .unwrap();
    assert!(error.to_string().contains("TTS_CANCELLED"));
    assert_eq!(transport.calls.load(Ordering::SeqCst), 1);
    transport.release.notify_one();
    let first = first.await.unwrap().unwrap();
    let second = synthesize_cloud_tts(
        &OpenAiCloudTtsProvider,
        transport.as_ref(),
        &e,
        &r,
        &directory.0,
        &TtsCancellation::default(),
    )
    .await
    .unwrap();
    assert!(second.from_cache);
    assert_eq!(transport.calls.load(Ordering::SeqCst), 1);
    drop(first);
    drop(second);
}
#[tokio::test]
async fn inflight_cancel_does_not_publish_and_releases_activity() {
    let directory = Directory::new();
    let transport = Arc::new(Transport {
        blocking: true,
        ..Transport::new()
    });
    let cancel = TtsCancellation::default();
    let c = cancel.clone();
    let dir = directory.0.clone();
    let t = transport.clone();
    let task = tokio::spawn(async move {
        synthesize_cloud_tts(
            &OpenAiCloudTtsProvider,
            t.as_ref(),
            &engine(),
            &request(),
            &dir,
            &c,
        )
        .await
    });
    transport.entered.notified().await;
    cancel.cancel();
    let error = tokio::time::timeout(Duration::from_secs(1), task)
        .await
        .unwrap()
        .unwrap()
        .err()
        .unwrap();
    assert!(error.to_string().contains("TTS_CANCELLED"));
    assert!(std::fs::read_dir(&directory.0).unwrap().next().is_none());
    let path = directory.0.join("tts_fixture.wav");
    std::fs::write(&path, wav()).unwrap();
    assert_eq!(
        TtsCache::open(&directory.0)
            .unwrap()
            .clear(None, None, None, None)
            .unwrap()
            .removed_files,
        1
    );
}
#[tokio::test]
async fn error_bodies_empty_audio_and_redirects_do_not_cache_or_leak_key() {
    for (status, mime, bytes) in [
        (
            401,
            "application/json",
            b"{\"error\":\"local-fixture-key\"}".to_vec(),
        ),
        (200, "application/problem+json", b"{}".to_vec()),
        (200, "text/html", b"login".to_vec()),
        (302, "audio/wav", wav()),
        (200, "audio/wav", vec![]),
        (
            200,
            "audio/mpeg",
            br#"{"error":"local-fixture-key"}"#.to_vec(),
        ),
        (
            200,
            "application/octet-stream",
            b"<html>failed</html>".to_vec(),
        ),
    ] {
        let dir = Directory::new();
        let t = Transport {
            status,
            mime: mime.into(),
            bytes,
            ..Transport::new()
        };
        let error = synthesize_cloud_tts(
            &OpenAiCloudTtsProvider,
            &t,
            &engine(),
            &request(),
            &dir.0,
            &TtsCancellation::default(),
        )
        .await
        .err()
        .unwrap();
        assert!(!error.to_string().contains("local-fixture-key"));
        assert!(std::fs::read_dir(&dir.0).unwrap().next().is_none());
    }
}
#[tokio::test]
async fn pcm_and_opus_use_formats_supported_by_shared_cache() {
    for (format, extension, mime, bytes) in [
        ("pcm", "wav", "audio/wav", vec![1, 2, 3, 4]),
        ("opus", "ogg", "audio/ogg", b"OggS_fixture".to_vec()),
    ] {
        let directory = Directory::new();
        let t = Transport {
            bytes,
            ..Transport::new()
        };
        let mut r = request();
        r.format = format.into();
        let first = synthesize_cloud_tts(
            &OpenAiCloudTtsProvider,
            &t,
            &engine(),
            &r,
            &directory.0,
            &TtsCancellation::default(),
        )
        .await
        .unwrap();
        assert_eq!(first.audio_path.extension().unwrap(), extension);
        assert_eq!(first.content_type, mime);
        let cached = synthesize_cloud_tts(
            &OpenAiCloudTtsProvider,
            &t,
            &engine(),
            &r,
            &directory.0,
            &TtsCancellation::default(),
        )
        .await
        .unwrap();
        assert!(cached.from_cache);
        assert_eq!(cached.content_type, mime);
        assert_eq!(
            TtsCache::open(&directory.0).unwrap().list().unwrap().len(),
            1
        );
    }
}

#[tokio::test]
async fn two_live_consumers_share_one_inflight_synthesis() {
    let directory = Directory::new();
    let t = Arc::new(Transport {
        blocking: true,
        ..Transport::new()
    });
    let dir = directory.0.clone();
    let transport = t.clone();
    let first = tokio::spawn(async move {
        synthesize_cloud_tts(
            &OpenAiCloudTtsProvider,
            transport.as_ref(),
            &engine(),
            &request(),
            &dir,
            &TtsCancellation::default(),
        )
        .await
    });
    t.entered.notified().await;
    let dir = directory.0.clone();
    let transport = t.clone();
    let second = tokio::spawn(async move {
        synthesize_cloud_tts(
            &OpenAiCloudTtsProvider,
            transport.as_ref(),
            &engine(),
            &request(),
            &dir,
            &TtsCancellation::default(),
        )
        .await
    });
    tokio::task::yield_now().await;
    t.release.notify_one();
    let (first, second) = tokio::join!(first, second);
    let first = first.unwrap().unwrap();
    let second = second.unwrap().unwrap();
    assert_eq!(first.audio_path, second.audio_path);
    assert!(!first.from_cache);
    assert!(second.from_cache);
    assert_eq!(t.calls.load(Ordering::SeqCst), 1);
    drop(first);
    drop(second);
}
#[tokio::test]
async fn already_cancelled_request_has_no_filesystem_or_network_side_effect() {
    let directory = Directory::new();
    let absent = directory.0.join("must-not-create");
    let cancellation = TtsCancellation::default();
    cancellation.cancel();
    let transport = Transport::new();
    assert!(
        synthesize_cloud_tts(
            &OpenAiCloudTtsProvider,
            &transport,
            &engine(),
            &request(),
            &absent,
            &cancellation
        )
        .await
        .is_err()
    );
    assert!(!absent.exists());
    assert_eq!(transport.calls.load(Ordering::SeqCst), 0);
}

fn mimo_engine() -> CloudTtsEngine {
    CloudTtsEngine {
        provider: CloudTtsProviderType::Mimo,
        model: "mimo-v2.5-tts".into(),
        ..engine()
    }
}
fn mimo_request() -> CloudTtsSynthesisRequest {
    CloudTtsSynthesisRequest {
        voice_id: "冰糖".into(),
        format: "wav".into(),
        ..request()
    }
}
fn mimo_stream() -> Vec<u8> {
    b"data: {\"choices\":[{\"delta\":{\"audio\":{\"data\":\"AAEAAg==\"}}}]}\n\ndata: [DONE]\n\n"
        .to_vec()
}
#[tokio::test]
async fn mimo_stream_cached_as_wav_and_shared_lease_is_protected() {
    let directory = Directory::new();
    let transport = Transport {
        mime: "text/event-stream; charset=utf-8".into(),
        bytes: mimo_stream(),
        ..Transport::new()
    };
    let e = mimo_engine();
    let r = mimo_request();
    let c = TtsCancellation::default();
    let provider = cloud_tts_provider(e.provider);
    let first = synthesize_cloud_tts(provider, &transport, &e, &r, &directory.0, &c)
        .await
        .unwrap();
    assert_eq!(std::fs::read(&first.audio_path).unwrap(), wav());
    assert_eq!(first.content_type, "audio/wav");
    let mut playback = r.clone();
    playback.speed = 2.0;
    let hit = synthesize_cloud_tts(provider, &transport, &e, &playback, &directory.0, &c)
        .await
        .unwrap();
    assert!(hit.from_cache);
    assert_eq!(transport.calls.load(Ordering::SeqCst), 1);
    let cache = TtsCache::open(&directory.0).unwrap();
    assert_eq!(
        cache.clear(None, None, None, None).unwrap().removed_files,
        0
    );
    drop(first);
    drop(hit);
    assert_eq!(
        cache.clear(None, None, None, None).unwrap().removed_files,
        1
    );
}
#[tokio::test]
async fn mimo_invalid_stream_and_cancelled_download_leave_no_audio() {
    for (mime, bytes) in [
        (
            "application/json",
            b"{\"error\":\"fixture-private\"}".to_vec(),
        ),
        (
            "text/event-stream",
            mimo_stream()
                .split(|b| *b == b'\n')
                .next()
                .unwrap()
                .to_vec(),
        ),
        ("text/event-stream", b"event: error\ndata: {}\n\n".to_vec()),
    ] {
        let directory = Directory::new();
        let t = Transport {
            mime: mime.into(),
            bytes,
            ..Transport::new()
        };
        let error = synthesize_cloud_tts(
            cloud_tts_provider(CloudTtsProviderType::Mimo),
            &t,
            &mimo_engine(),
            &mimo_request(),
            &directory.0,
            &TtsCancellation::default(),
        )
        .await
        .err()
        .unwrap();
        assert!(!error.to_string().contains("fixture-private"));
        assert!(
            TtsCache::open(&directory.0)
                .unwrap()
                .list()
                .unwrap()
                .is_empty()
        );
    }
    let directory = Directory::new();
    let transport = Arc::new(Transport {
        blocking: true,
        mime: "text/event-stream".into(),
        bytes: mimo_stream(),
        ..Transport::new()
    });
    let cancellation = TtsCancellation::default();
    let t = transport.clone();
    let c = cancellation.clone();
    let path = directory.0.clone();
    let pending = tokio::spawn(async move {
        synthesize_cloud_tts(
            cloud_tts_provider(CloudTtsProviderType::Mimo),
            t.as_ref(),
            &mimo_engine(),
            &mimo_request(),
            &path,
            &c,
        )
        .await
    });
    transport.entered.notified().await;
    cancellation.cancel();
    assert!(
        tokio::time::timeout(Duration::from_secs(1), pending)
            .await
            .unwrap()
            .unwrap()
            .is_err()
    );
    assert!(
        TtsCache::open(&directory.0)
            .unwrap()
            .list()
            .unwrap()
            .is_empty()
    );
}
