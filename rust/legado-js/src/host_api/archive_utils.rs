//! 解压缩宿主 API
//!
//! 对应 Kotlin `ArchiveUtils.kt`，提供 ZIP / 7z / RAR 解压能力。
//! - ZIP：使用 `zip` crate 完整实现
//! - 7z：使用 `sevenz-rust2` crate 纯 Rust 实现（需 quickjs feature）
//! - RAR：不安全的后端已停用，所有入口明确拒绝
//! - raw-deflate：使用 `flate2` crate（需 quickjs feature），供
//!   `java.util.zip.Inflater` 语料面（`java.inflateRawBytes` 宿主桥）

use std::fs;
use std::io::Read;
use std::path::Path;

/// unzipFile(zipPath, outputPath?) — 解压 ZIP 文件
///
/// 将 `zip_path` 指向的 ZIP 文件解压到 `output_path`（默认为 ZIP 同目录下同名文件夹）。
/// 返回解压目标目录路径。
pub fn unzip_file(zip_path: &str, output_path: Option<&str>) -> Result<String, String> {
    let zip_path = Path::new(zip_path);
    if !zip_path.exists() {
        return Err(format!("ZIP file not found: {}", zip_path.display()));
    }

    let out_dir = match output_path {
        Some(p) => p.to_string(),
        None => {
            // 默认输出到同目录下去掉扩展名的文件夹
            let stem = zip_path
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("unzipped");
            let parent = zip_path.parent().unwrap_or(Path::new("."));
            parent.join(stem).to_string_lossy().to_string()
        }
    };

    let file = fs::File::open(zip_path).map_err(|e| format!("Failed to open ZIP: {e}"))?;
    let mut archive =
        zip::ZipArchive::new(file).map_err(|e| format!("Invalid ZIP archive: {e}"))?;

    fs::create_dir_all(&out_dir).map_err(|e| format!("Failed to create output dir: {e}"))?;

    for i in 0..archive.len() {
        let mut entry = archive
            .by_index(i)
            .map_err(|e| format!("Failed to read ZIP entry {i}: {e}"))?;

        // 使用 enclosed_name 防止路径穿越
        let entry_name = match entry.enclosed_name() {
            Some(name) => name.to_path_buf(),
            None => continue, // 跳过不安全路径
        };

        let target = Path::new(&out_dir).join(&entry_name);

        if entry.is_dir() {
            fs::create_dir_all(&target)
                .map_err(|e| format!("Failed to create dir {}: {e}", target.display()))?;
        } else {
            // 确保父目录存在
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent)
                    .map_err(|e| format!("Failed to create dir {}: {e}", parent.display()))?;
            }
            let mut buf = Vec::new();
            entry
                .read_to_end(&mut buf)
                .map_err(|e| format!("Failed to read entry {}: {e}", entry_name.display()))?;
            fs::write(&target, &buf)
                .map_err(|e| format!("Failed to write {}: {e}", target.display()))?;
        }
    }

    Ok(out_dir)
}

/// getZipStringContent(zipPath, entryName) — 读取 ZIP 中指定文件内容（UTF-8 字符串）
pub fn get_zip_string_content(zip_path: &str, entry_name: &str) -> Result<String, String> {
    let bytes = get_zip_byte_array_content(zip_path, entry_name)?;
    String::from_utf8(bytes).map_err(|e| format!("Entry is not valid UTF-8: {e}"))
}

/// getZipByteArrayContent(zipPath, entryName) — 读取 ZIP 中指定文件的字节
pub fn get_zip_byte_array_content(zip_path: &str, entry_name: &str) -> Result<Vec<u8>, String> {
    let zip_path = Path::new(zip_path);
    if !zip_path.exists() {
        return Err(format!("ZIP file not found: {}", zip_path.display()));
    }

    let file = fs::File::open(zip_path).map_err(|e| format!("Failed to open ZIP: {e}"))?;
    let mut archive =
        zip::ZipArchive::new(file).map_err(|e| format!("Invalid ZIP archive: {e}"))?;

    let mut entry = archive
        .by_name(entry_name)
        .map_err(|e| format!("Entry '{entry_name}' not found in ZIP: {e}"))?;

    let mut buf = Vec::new();
    entry
        .read_to_end(&mut buf)
        .map_err(|e| format!("Failed to read entry '{entry_name}': {e}"))?;

    Ok(buf)
}

/// zipEntryBytes(zipBytes, entryName) — 从内存中的 ZIP 字节数据读取指定条目
///
/// 对应 Kotlin `getZipByteArrayContent` 的 ZipInputStream 逻辑：
/// 用于网络 ZIP / 十六进制字符串等非本地文件场景。
pub fn zip_entry_bytes(zip_bytes: &[u8], entry_name: &str) -> Result<Vec<u8>, String> {
    zip_entry_bytes_optional(zip_bytes, entry_name)?
        .ok_or_else(|| format!("Entry '{entry_name}' not found in ZIP"))
}

/// 不存在的条目与坏档案/CRC读取失败分别返回None与Err。
pub(crate) fn zip_entry_bytes_optional(
    zip_bytes: &[u8],
    entry_name: &str,
) -> Result<Option<Vec<u8>>, String> {
    let cursor = std::io::Cursor::new(zip_bytes);
    let mut archive =
        zip::ZipArchive::new(cursor).map_err(|e| format!("Invalid ZIP archive: {e}"))?;

    let mut entry = match archive.by_name(entry_name) {
        Ok(entry) => entry,
        Err(zip::result::ZipError::FileNotFound) => return Ok(None),
        Err(error) => return Err(format!("读取ZIP条目失败: {error}")),
    };

    let mut buf = Vec::new();
    entry
        .read_to_end(&mut buf)
        .map_err(|e| format!("Failed to read entry '{entry_name}': {e}"))?;

    Ok(Some(buf))
}

/// un7zFile(7zPath, outputPath?) — 解压 7z 文件
///
/// 使用 `sevenz-rust2` 纯 Rust 实现解压 7z 格式文件。
/// 支持 LZMA/LZMA2/COPY 等编解码器。
/// 返回解压目标目录路径。
#[cfg(feature = "quickjs")]
pub fn un7z_file(seven_z_path: &str, output_path: Option<&str>) -> Result<String, String> {
    let src = Path::new(seven_z_path);
    if !src.exists() {
        return Err(format!("7z file not found: {}", src.display()));
    }

    let out_dir = match output_path {
        Some(p) => p.to_string(),
        None => {
            let stem = src
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("un7zipped");
            let parent = src.parent().unwrap_or(Path::new("."));
            parent.join(stem).to_string_lossy().to_string()
        }
    };

    sevenz_rust2::decompress_file(src, &out_dir)
        .map_err(|e| format!("7z decompression failed: {e}"))?;

    Ok(out_dir)
}

/// un7zFile — 无 quickjs feature 时的回退桩
#[cfg(not(feature = "quickjs"))]
pub fn un7z_file(_seven_z_path: &str, _output_path: Option<&str>) -> Result<String, String> {
    Err("[ERROR] 7z decompression requires 'quickjs' feature (sevenz-rust2)".to_string())
}

/// 不安全的 RAR 后端已停用，任何构建档均不得触碰输入或输出路径。
pub const RAR_UNSUPPORTED: &str = "JS RAR 功能暂不支持";

pub fn unrar_file(_rar_path: &str, _output_path: Option<&str>) -> Result<String, String> {
    Err(RAR_UNSUPPORTED.to_string())
}

/// sevenZEntryBytes — 从内存中的 7z 字节数据读取指定条目
///
/// 对应 Kotlin `get7zByteArrayContent` 的流式读取逻辑：
/// 用于网络 7z / 十六进制字符串等非本地文件场景。
#[cfg(feature = "quickjs")]
pub fn seven_z_entry_bytes(seven_z_bytes: &[u8], entry_name: &str) -> Result<Vec<u8>, String> {
    seven_z_entry_bytes_optional(seven_z_bytes, entry_name)?
        .ok_or_else(|| format!("Entry '{entry_name}' not found in 7z"))
}

#[cfg(feature = "quickjs")]
pub(crate) fn seven_z_entry_bytes_optional(
    seven_z_bytes: &[u8],
    entry_name: &str,
) -> Result<Option<Vec<u8>>, String> {
    let cursor = std::io::Cursor::new(seven_z_bytes);
    let mut reader = sevenz_rust2::ArchiveReader::new(cursor, sevenz_rust2::Password::empty())
        .map_err(|e| format!("Invalid 7z archive: {e}"))?;
    match reader.read_file(entry_name) {
        Ok(bytes) => Ok(Some(bytes)),
        Err(sevenz_rust2::Error::FileNotFound) => Ok(None),
        Err(error) => Err(format!("读取7z条目失败: {error}")),
    }
}

/// sevenZEntryBytes — 无 quickjs feature 时的回退桩
#[cfg(not(feature = "quickjs"))]
pub fn seven_z_entry_bytes(_seven_z_bytes: &[u8], _entry_name: &str) -> Result<Vec<u8>, String> {
    Err("[ERROR] 7z entry reading requires 'quickjs' feature (sevenz-rust2)".to_string())
}

/// unArchiveFile(archivePath, outputPath?) — 通用解压（自动检测格式）
///
/// 根据文件头 magic bytes 检测压缩格式，分派到对应解压函数。
pub fn un_archive_file(archive_path: &str, output_path: Option<&str>) -> Result<String, String> {
    let magic = read_file_magic(archive_path)?;
    match magic.as_str() {
        "PK" => unzip_file(archive_path, output_path),
        "7z" => un7z_file(archive_path, output_path),
        "Rar" => unrar_file(archive_path, output_path),
        _ => Err(format!(
            "Unknown archive format for file: {archive_path} (magic: {magic})"
        )),
    }
}

/// 读取文件头部 magic bytes 以判断压缩格式
fn read_file_magic(path: &str) -> Result<String, String> {
    let data = fs::read(path).map_err(|e| format!("Failed to read file '{path}': {e}"))?;
    if data.len() >= 4 {
        if &data[0..2] == b"PK" {
            return Ok("PK".to_string());
        }
        if &data[0..2] == b"7z" {
            return Ok("7z".to_string());
        }
        if &data[0..4] == b"Rar!" {
            return Ok("Rar".to_string());
        }
    } else if data.len() >= 2 {
        if &data[0..2] == b"PK" {
            return Ok("PK".to_string());
        }
        if &data[0..2] == b"7z" {
            return Ok("7z".to_string());
        }
    }
    Ok("unknown".to_string())
}

/// `java.inflateRawBytes(data)` — raw-deflate 解压（无 zlib/gzip 头）
///
/// P2-9 ①：语料 `java.util.zip.Inflater` 流程（2 个源）中
/// `new Inflater(true)` 的 `true` 即 no-wrap（raw deflate）。
/// 先按 raw deflate 解压；未完整消费输入时再按 zlib 封装
/// （windowBits=15，带 2 字节头 + adler32 尾）宽容重试；
/// 均失败 → 可捕获错误（JS 侧 try/catch 降级为空串，不炸整条规则）。
#[cfg(feature = "quickjs")]
pub fn inflate_raw_bytes(data: &[u8]) -> Result<Vec<u8>, String> {
    use flate2::{Decompress, FlushDecompress, Status};

    if data.is_empty() {
        return Ok(Vec::new());
    }
    // 单次尝试：全新 Decompress + 逐次扩容的输出缓冲（无状态机跨调用
    // 输出偏移语义，避免脏读）。flate2::Status：Ok/BufError = 需更多
    // 空间继续，StreamEnd = 流完整结束（对齐 Java Inflater：解到流尾即止，
    // 尾部多余字节忽略）。
    fn attempt(no_wrap: bool, data: &[u8]) -> Result<Vec<u8>, String> {
        for attempt in 0..8u32 {
            let cap = (data.len() as u64 * 2u64.saturating_pow(attempt) + 64)
                .clamp(1024, 64 * 1024 * 1024) as usize;
            let mut out = vec![0u8; cap];
            let mut d = Decompress::new(no_wrap);
            let status = match d.decompress(data, &mut out, FlushDecompress::Finish) {
                Ok(s) => s,
                Err(e) => return Err(format!("inflateRawBytes: 流损坏（{e}）")),
            };
            if status == Status::StreamEnd {
                out.truncate(d.total_out() as usize);
                return Ok(out);
            }
            // Ok / BufError：输出缓冲不足或流未结束 → 扩容重试
        }
        Err(format!(
            "inflateRawBytes: 解压未完成（{} 字节数据）",
            data.len()
        ))
    }

    // 1) zlib 封装优先：flate2 `Decompress::new(zlib_header=true)` 即 zlib 解码
    //    （等价 Java `Inflater(false)`）；P2-11 §197：原注释极性与实现相反，已更正
    if let Ok(v) = attempt(true, data) {
        return Ok(v);
    }
    // 2) 宽容重试：裸 deflate（`Decompress::new(false)`，等价 Java `Inflater(true)`
    //    的 nowrap 语义）
    if let Ok(v) = attempt(false, data) {
        return Ok(v);
    }
    Err(format!(
        "inflateRawBytes: 非合法 deflate/zlib 数据（{} 字节）",
        data.len()
    ))
}

// ============================================================
// 单元测试
// ============================================================
#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use zip::ZipWriter;
    use zip::write::SimpleFileOptions;

    /// 辅助：创建包含指定条目的测试 ZIP 文件，返回 ZIP 路径
    fn create_test_zip(entries: &[(&str, &[u8])]) -> String {
        let dir = std::env::temp_dir().join(format!("legado_archive_test_{}", uuid()));
        fs::create_dir_all(&dir).unwrap();
        let zip_path = dir.join("test.zip");

        let file = fs::File::create(&zip_path).unwrap();
        let mut writer = ZipWriter::new(file);
        let options =
            SimpleFileOptions::default().compression_method(zip::CompressionMethod::Stored);

        for (name, content) in entries {
            writer.start_file(*name, options).unwrap();
            writer.write_all(content).unwrap();
        }
        writer.finish().unwrap();

        zip_path.to_string_lossy().to_string()
    }

    /// 简单 UUID（避免测试依赖 uuid crate feature；进程内递增序号防并发撞刻）
    fn uuid() -> String {
        use std::sync::atomic::{AtomicU64, Ordering};
        use std::time::{SystemTime, UNIX_EPOCH};
        static COUNTER: AtomicU64 = AtomicU64::new(0);
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .subsec_nanos();
        // 进程内单调序号：防两次并发 create_test_zip 落在同一时钟刻（SystemTime
        // 粒度较粗）撞目录——共享 test.zip 被截断 / 目录被先结束者删掉的 flake
        let seq = COUNTER.fetch_add(1, Ordering::Relaxed);
        format!("{:x}{:x}{:x}", std::process::id(), nanos, seq)
    }

    #[test]
    fn test_unzip_file_basic() {
        let zip_path = create_test_zip(&[
            ("hello.txt", b"Hello World"),
            ("sub/data.bin", &[0x01, 0x02, 0x03]),
        ]);

        let out_dir = std::env::temp_dir().join(format!("legado_unzip_out_{}", uuid()));
        let result = unzip_file(&zip_path, Some(out_dir.to_str().unwrap()));
        assert!(result.is_ok());

        let out = result.unwrap();
        assert!(Path::new(&out).join("hello.txt").exists());
        assert!(Path::new(&out).join("sub/data.bin").exists());

        let content = fs::read_to_string(Path::new(&out).join("hello.txt")).unwrap();
        assert_eq!(content, "Hello World");

        // 清理
        let _ = fs::remove_dir_all(&out);
        let _ = fs::remove_dir_all(Path::new(&zip_path).parent().unwrap());
    }

    #[test]
    fn test_unzip_file_default_output() {
        let zip_path = create_test_zip(&[("a.txt", b"aaa")]);
        let result = unzip_file(&zip_path, None);
        assert!(result.is_ok());

        let out = result.unwrap();
        // 默认输出目录为 ZIP 同目录下 "test" 文件夹
        assert!(out.ends_with("test"));
        assert!(Path::new(&out).join("a.txt").exists());

        let _ = fs::remove_dir_all(&out);
        let _ = fs::remove_dir_all(Path::new(&zip_path).parent().unwrap());
    }

    #[test]
    fn test_unzip_file_not_found() {
        let result = unzip_file("/nonexistent/path.zip", None);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not found"));
    }

    #[test]
    fn test_get_zip_string_content() {
        let zip_path = create_test_zip(&[("readme.md", b"# Title\nContent here")]);
        let result = get_zip_string_content(&zip_path, "readme.md");
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), "# Title\nContent here");

        let _ = fs::remove_dir_all(Path::new(&zip_path).parent().unwrap());
    }

    #[test]
    fn test_get_zip_string_content_not_found_entry() {
        let zip_path = create_test_zip(&[("a.txt", b"data")]);
        let result = get_zip_string_content(&zip_path, "nonexistent.txt");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not found"));

        let _ = fs::remove_dir_all(Path::new(&zip_path).parent().unwrap());
    }

    #[test]
    fn test_get_zip_byte_array_content() {
        let data: &[u8] = &[0xDE, 0xAD, 0xBE, 0xEF];
        let zip_path = create_test_zip(&[("binary.bin", data)]);
        let result = get_zip_byte_array_content(&zip_path, "binary.bin");
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), vec![0xDE, 0xAD, 0xBE, 0xEF]);

        let _ = fs::remove_dir_all(Path::new(&zip_path).parent().unwrap());
    }

    #[test]
    fn test_get_zip_byte_array_content_zip_not_found() {
        let result = get_zip_byte_array_content("/no/such/file.zip", "entry");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not found"));
    }

    #[test]
    fn test_zip_entry_bytes_from_memory() {
        let content = "内存 ZIP 内容";
        let zip_path = create_test_zip(&[("inner.txt", content.as_bytes())]);
        let zip_bytes = fs::read(&zip_path).unwrap();

        let result = zip_entry_bytes(&zip_bytes, "inner.txt");
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), content.as_bytes().to_vec());

        // 不存在的条目应报错
        assert!(zip_entry_bytes(&zip_bytes, "no-such.txt").is_err());
        // 非法 ZIP 数据应报错
        assert!(zip_entry_bytes(b"not a zip", "a").is_err());

        let _ = fs::remove_dir_all(Path::new(&zip_path).parent().unwrap());
    }

    #[test]
    fn test_un7z_file_not_found() {
        let result = un7z_file("/nonexistent/path.7z", None);
        assert!(result.is_err());
        let err = result.unwrap_err();
        // quickjs feature 启用时报 "not found"，否则报 feature 提示
        assert!(err.contains("not found") || err.contains("quickjs"));
    }

    #[test]
    fn rar_is_rejected_without_touching_paths() {
        let dir = std::env::temp_dir().join(format!("legado_disabled_rar_{}", uuid()));
        assert_eq!(
            unrar_file("missing.rar", Some(dir.to_str().unwrap())),
            Err(RAR_UNSUPPORTED.into())
        );
        assert!(!dir.exists());
    }

    #[test]
    #[cfg(feature = "quickjs")]
    fn test_seven_z_entry_bytes_basic() {
        let seven_z_path = create_test_7z(&[
            ("chapter.txt", "第七章 内容文本".as_bytes()),
            ("sub/data.bin", &[0x11, 0x22]),
        ]);
        let bytes = fs::read(&seven_z_path).unwrap();

        // 读取存在的条目
        let content = seven_z_entry_bytes(&bytes, "chapter.txt");
        assert!(
            content.is_ok(),
            "seven_z_entry_bytes failed: {:?}",
            content.err()
        );
        assert_eq!(
            String::from_utf8(content.unwrap()).unwrap(),
            "第七章 内容文本"
        );

        // 子目录条目
        let bin = seven_z_entry_bytes(&bytes, "sub/data.bin").unwrap();
        assert_eq!(bin, vec![0x11, 0x22]);

        // 不存在的条目应报错
        assert!(seven_z_entry_bytes(&bytes, "no-such.txt").is_err());
        // 非法 7z 数据应报错
        assert!(seven_z_entry_bytes(b"not a 7z", "a").is_err());

        let _ = fs::remove_dir_all(Path::new(&seven_z_path).parent().unwrap());
    }

    #[test]
    fn test_un_archive_file_zip() {
        let zip_path = create_test_zip(&[("file.txt", b"archive content")]);
        let out_dir = std::env::temp_dir().join(format!("legado_unarchive_{}", uuid()));
        let result = un_archive_file(&zip_path, Some(out_dir.to_str().unwrap()));
        assert!(result.is_ok());
        assert!(Path::new(&result.unwrap()).join("file.txt").exists());

        let _ = fs::remove_dir_all(&out_dir);
        let _ = fs::remove_dir_all(Path::new(&zip_path).parent().unwrap());
    }

    #[test]
    fn test_un_archive_file_unknown_format() {
        // 创建一个非压缩文件
        let dir = std::env::temp_dir().join(format!("legado_unknown_{}", uuid()));
        fs::create_dir_all(&dir).unwrap();
        let file_path = dir.join("data.xyz");
        fs::write(&file_path, b"not an archive").unwrap();

        let result = un_archive_file(file_path.to_str().unwrap(), None);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Unknown archive format"));

        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_read_file_magic_zip() {
        let zip_path = create_test_zip(&[("x.txt", b"x")]);
        let magic = read_file_magic(&zip_path).unwrap();
        assert_eq!(magic, "PK");

        let _ = fs::remove_dir_all(Path::new(&zip_path).parent().unwrap());
    }

    #[test]
    fn test_read_file_magic_7z() {
        let dir = std::env::temp_dir().join(format!("legado_magic7z_{}", uuid()));
        fs::create_dir_all(&dir).unwrap();
        let file_path = dir.join("test.7z");
        // 7z magic: 37 7A BC AF 27 1C
        fs::write(&file_path, [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]).unwrap();

        let magic = read_file_magic(file_path.to_str().unwrap()).unwrap();
        assert_eq!(magic, "7z");

        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_read_file_magic_rar() {
        let dir = std::env::temp_dir().join(format!("legado_magicrar_{}", uuid()));
        fs::create_dir_all(&dir).unwrap();
        let file_path = dir.join("test.rar");
        fs::write(&file_path, b"Rar!\x1a\x07\x00").unwrap();

        let magic = read_file_magic(file_path.to_str().unwrap()).unwrap();
        assert_eq!(magic, "Rar");

        let _ = fs::remove_dir_all(&dir);
    }

    // ============================================================
    // 7z 解压测试（需要 quickjs feature 启用 sevenz-rust2）
    // ============================================================

    /// 辅助：创建包含指定文件的测试 7z 压缩包，返回 7z 文件路径
    #[cfg(feature = "quickjs")]
    fn create_test_7z(entries: &[(&str, &[u8])]) -> String {
        let dir = std::env::temp_dir().join(format!("legado_7z_src_{}", uuid()));
        fs::create_dir_all(&dir).unwrap();

        // 先创建源文件
        for (name, content) in entries {
            let file_path = dir.join(name);
            if let Some(parent) = file_path.parent() {
                fs::create_dir_all(parent).unwrap();
            }
            fs::write(&file_path, content).unwrap();
        }

        // 压缩为 7z
        let seven_z_path = std::env::temp_dir()
            .join(format!("legado_7z_archive_{}", uuid()))
            .join("test.7z");
        if let Some(parent) = seven_z_path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        sevenz_rust2::compress_to_path(&dir, &seven_z_path).unwrap();

        // 清理源文件目录
        let _ = fs::remove_dir_all(&dir);

        seven_z_path.to_string_lossy().to_string()
    }

    #[test]
    #[cfg(feature = "quickjs")]
    fn test_un7z_file_basic() {
        let seven_z_path = create_test_7z(&[
            ("hello.txt", b"Hello 7z World"),
            ("sub/data.bin", &[0xCA, 0xFE, 0xBA, 0xBE]),
        ]);

        let out_dir = std::env::temp_dir().join(format!("legado_7z_out_{}", uuid()));
        let result = un7z_file(&seven_z_path, Some(out_dir.to_str().unwrap()));
        assert!(result.is_ok(), "un7z_file failed: {:?}", result.err());

        let out = result.unwrap();
        assert!(Path::new(&out).join("hello.txt").exists());
        assert!(Path::new(&out).join("sub/data.bin").exists());

        let content = fs::read_to_string(Path::new(&out).join("hello.txt")).unwrap();
        assert_eq!(content, "Hello 7z World");

        let bin = fs::read(Path::new(&out).join("sub/data.bin")).unwrap();
        assert_eq!(bin, vec![0xCA, 0xFE, 0xBA, 0xBE]);

        // 清理
        let _ = fs::remove_dir_all(&out);
        let _ = fs::remove_dir_all(Path::new(&seven_z_path).parent().unwrap());
    }

    #[test]
    #[cfg(feature = "quickjs")]
    fn test_un7z_file_default_output() {
        let seven_z_path = create_test_7z(&[("readme.md", b"# 7z Test")]);
        let result = un7z_file(&seven_z_path, None);
        assert!(result.is_ok(), "un7z_file failed: {:?}", result.err());

        let out = result.unwrap();
        // 默认输出目录为 7z 同目录下 "test" 文件夹
        assert!(
            out.ends_with("test"),
            "output dir should end with 'test', got: {out}"
        );
        assert!(Path::new(&out).join("readme.md").exists());

        let content = fs::read_to_string(Path::new(&out).join("readme.md")).unwrap();
        assert_eq!(content, "# 7z Test");

        let _ = fs::remove_dir_all(&out);
        let _ = fs::remove_dir_all(Path::new(&seven_z_path).parent().unwrap());
    }

    #[test]
    #[cfg(feature = "quickjs")]
    fn test_un_archive_file_7z() {
        let seven_z_path = create_test_7z(&[("content.txt", b"auto detect 7z")]);
        let out_dir = std::env::temp_dir().join(format!("legado_unarchive7z_{}", uuid()));
        let result = un_archive_file(&seven_z_path, Some(out_dir.to_str().unwrap()));
        assert!(
            result.is_ok(),
            "un_archive_file 7z failed: {:?}",
            result.err()
        );

        let out = result.unwrap();
        assert!(Path::new(&out).join("content.txt").exists());
        let content = fs::read_to_string(Path::new(&out).join("content.txt")).unwrap();
        assert_eq!(content, "auto detect 7z");

        let _ = fs::remove_dir_all(&out);
        let _ = fs::remove_dir_all(Path::new(&seven_z_path).parent().unwrap());
    }

    /// P2-9 ①：raw-deflate 解压（Inflater(true) 语料面）+ zlib 宽容回退
    #[test]
    #[cfg(feature = "quickjs")]
    fn test_inflate_raw_bytes() {
        use flate2::Compression;
        use flate2::write::{DeflateEncoder, ZlibEncoder};
        use std::io::Write as _;

        let payload = b"legado-inflate-raw-test-\xE6\x95\xB0\xE6\x8D\xAE-1234567890";
        // raw deflate（DeflateEncoder 输出即无 zlib 头）
        let mut raw = Vec::new();
        {
            let mut enc = DeflateEncoder::new(raw, Compression::fast());
            enc.write_all(payload).unwrap();
            raw = enc.finish().unwrap();
        }
        assert_eq!(inflate_raw_bytes(&raw).unwrap(), payload);

        // zlib 封装数据走宽容回退路径
        let mut zlib = Vec::new();
        {
            let mut enc = ZlibEncoder::new(zlib, Compression::fast());
            enc.write_all(payload).unwrap();
            zlib = enc.finish().unwrap();
        }
        assert_eq!(inflate_raw_bytes(&zlib).unwrap(), payload);

        // 垃圾数据 → 可捕获错误（不 panic）
        assert!(inflate_raw_bytes(b"not-deflate-garbage-data").is_err());
        // 空输入 → 空输出
        assert_eq!(inflate_raw_bytes(&[]).unwrap(), Vec::<u8>::new());
    }
}
