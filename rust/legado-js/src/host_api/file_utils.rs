//! 文件工具 API（沙箱化）
//!
//! 提供文件操作函数（沙箱内），对应 Kotlin 端 `JsExtensions` 中的文件方法：
//! - readFile — 读取文件内容
//! - writeFile — 写入文件
//! - fileExists — 检查文件是否存在
//! - deleteFile — 删除文件
//! - readTxtFile — 读取文本文件（支持编码）
//! - getTxtInFolder — 获取文件夹下文本文件内容
//!
//! 下载/文本缓存/脚本导入由私有file_download复用规则请求实现。
//! 所有路径操作均限制在沙箱目录内，防止路径穿越攻击。

// ============================================================
// quickjs feature 启用时的真实实现
// ============================================================
#[cfg(feature = "quickjs")]
mod impl_file_utils {
    use std::fs;
    use std::path::{Path, PathBuf};

    // 引入可选依赖 crate
    use encoding_rs;

    /// 默认沙箱根目录
    ///
    /// 对应 Kotlin: `appCtx.externalCache.absolutePath`
    /// 使用系统临时目录 + legado_js_cache 作为默认沙箱
    pub fn default_sandbox_root() -> PathBuf {
        std::env::temp_dir().join("legado_js_cache")
    }

    /// 兼容旧名称
    pub fn sandbox_root() -> PathBuf {
        default_sandbox_root()
    }

    /// 解析安全路径（沙箱校验：确保路径在沙箱目录内）
    ///
    /// - 相对路径：以沙箱根为基准拼接
    /// - 绝对路径：直接使用，但仍校验是否在沙箱内
    /// - 路径穿越（`..`）：检测并拒绝
    pub fn resolve_safe_path(path: &str) -> Result<PathBuf, String> {
        use std::path::Component;

        let sandbox_root = default_sandbox_root();
        if !sandbox_root.exists() {
            fs::create_dir_all(&sandbox_root)
                .map_err(|e| format!("Failed to create sandbox: {}", e))?;
        }

        // 词法检查：拒绝包含 .. 组件的路径（防止路径穿越）
        for component in Path::new(path).components() {
            if matches!(component, Component::ParentDir) {
                return Err(format!("Path traversal blocked: {}", path));
            }
        }

        let resolved = if Path::new(path).is_absolute() {
            PathBuf::from(path)
        } else {
            sandbox_root.join(path)
        };

        // 先拒绝沙箱外绝对路径，即使目标的父目录尚不存在。
        if !resolved.starts_with(&sandbox_root) {
            return Err(format!("Path traversal blocked: {}", path));
        }
        let canonical_sandbox = sandbox_root.canonicalize().map_err(|e| e.to_string())?;
        // 检查目标本身及最近存在的祖先，涵盖文件链接与缺少多级父目录的写入。
        // 不承诺抵御外部进程在检查后并发替换链接。
        for ancestor in resolved.ancestors() {
            match fs::symlink_metadata(ancestor) {
                Ok(_) => {
                    let actual = ancestor.canonicalize().map_err(|e| e.to_string())?;
                    if !actual.starts_with(&canonical_sandbox) {
                        return Err(format!("Path traversal blocked: {}", path));
                    }
                    break;
                }
                Err(error) if error.kind() == std::io::ErrorKind::NotFound => continue,
                Err(error) => return Err(error.to_string()),
            }
        }
        Ok(resolved)
    }

    /// Rust内部UTF-8文本辅助；脚本readFile使用字节入口read_file_bytes。
    pub fn read_file(relative_path: &str) -> Result<String, String> {
        let path = resolve_safe_path(relative_path)?;
        if !path.exists() {
            return Ok(String::new());
        }
        fs::read_to_string(&path).map_err(|e| format!("Read error: {}", e))
    }

    /// 读取文件内容（字节）
    pub fn read_file_bytes(relative_path: &str) -> Result<Option<Vec<u8>>, String> {
        let path = resolve_safe_path(relative_path)?;
        match fs::read(&path) {
            Ok(bytes) => Ok(Some(bytes)),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(None),
            Err(error) => Err(format!("读取文件失败: {error}")),
        }
    }

    /// 写入文件
    ///
    /// 对应 Kotlin: `writeFile(path, content)`
    pub fn write_file(relative_path: &str, content: &str) -> Result<(), String> {
        let path = resolve_safe_path(relative_path)?;
        // Ensure parent directory exists
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("Cannot create parent dir: {}", e))?;
        }
        fs::write(&path, content).map_err(|e| format!("Write error: {}", e))
    }

    /// 检查文件是否存在
    ///
    /// 对应 Kotlin: `getFile(path).exists()`
    pub fn file_exists(relative_path: &str) -> Result<bool, String> {
        let path = resolve_safe_path(relative_path)?;
        Ok(path.exists())
    }

    /// 删除文件
    ///
    /// 对应 Kotlin: `deleteFile(path)`
    pub fn delete_file(relative_path: &str) -> Result<bool, String> {
        let path = resolve_safe_path(relative_path)?;
        if path.exists() {
            fs::remove_file(&path).map_err(|e| format!("Delete error: {}", e))?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    /// 列出目录下所有文件名
    pub fn list_files(relative_path: &str) -> Result<Vec<String>, String> {
        let path = resolve_safe_path(relative_path)?;
        if !path.is_dir() {
            return Ok(Vec::new());
        }
        let entries = fs::read_dir(&path).map_err(|e| format!("ReadDir error: {}", e))?;
        let mut names = Vec::new();
        for entry in entries {
            let entry = entry.map_err(|e| format!("Entry error: {}", e))?;
            if let Some(name) = entry.file_name().to_str() {
                names.push(name.to_string());
            }
        }
        Ok(names)
    }

    // ============================================================
    // 新增文件 API
    // ============================================================

    /// readTxtFile(path, charset?) — 读取文本文件（支持编码指定）
    ///
    /// 对应 Kotlin: `readTxtFile(path, charset)`
    /// 未指定编码时自动检测，显式编码不被探测结果覆盖。
    pub fn read_txt_file(path: &str, charset: Option<&str>) -> Result<String, String> {
        match read_file_bytes(path)? {
            Some(bytes) => decode_text(&bytes, charset),
            None => Ok(String::new()),
        }
    }

    /// 普通文件与压缩条目共用编码语义，不把文本内容误当HTML响应扫描meta。
    pub(crate) fn decode_text(bytes: &[u8], charset: Option<&str>) -> Result<String, String> {
        match charset {
            None => Ok(legado_parser::response_decode::decode_detected_or_lossy(
                bytes,
            )),
            Some(label) => {
                let encoding = encoding_rs::Encoding::for_label(label.trim().as_bytes())
                    .ok_or_else(|| format!("不支持的字符集: {label}"))?;
                Ok(encoding.decode(bytes).0.into_owned())
            }
        }
    }

    /// 读取直接子文件并在全部成功后清理；不筛扩展名、不递归读取或删除子目录。
    pub fn get_txt_in_folder(folder_path: &str) -> Result<String, String> {
        if folder_path.is_empty() {
            return Ok(String::new());
        }
        let check_active = || crate::cancellation::check().map_err(|error| error.to_string());
        check_active()?;
        // 先按组件去掉尾部/.和重复分隔符，再检查链接；Unix的link/.元数据会跟随链接。
        // 不使用canonicalize替代该步骤，否则会提前丢失需要拒绝的目录别名。
        let resolved: PathBuf = resolve_safe_path(folder_path)?.components().collect();
        let metadata = fs::symlink_metadata(&resolved).map_err(|error| {
            if error.kind() == std::io::ErrorKind::NotFound {
                format!("Folder not found: {folder_path}")
            } else {
                format!("读取目录状态失败: {error}")
            }
        })?;
        let canonical = resolved.canonicalize().map_err(|error| error.to_string())?;
        let root = default_sandbox_root()
            .canonicalize()
            .map_err(|error| error.to_string())?;
        if canonical == root || !canonical.starts_with(&root) {
            return Err("不允许读取并清理脚本沙箱根目录或外部目录".into());
        }
        if !metadata.is_dir() || metadata.file_type().is_symlink() {
            return Err(format!("Not a directory or directory link: {folder_path}"));
        }
        // 也拒绝link/.或link/子目录形式，避免经目录别名清理另一个指定目录。
        let sandbox = default_sandbox_root();
        for ancestor in resolved
            .ancestors()
            .take_while(|path| *path != sandbox.as_path())
        {
            if fs::symlink_metadata(ancestor)
                .map_err(|error| format!("读取目录路径状态失败: {error}"))?
                .file_type()
                .is_symlink()
            {
                return Err("不允许通过目录链接读取并清理文件夹".into());
            }
        }
        // 先核对所有直接子项；目录/坏链接/非普通文件不能被跳过后一起删除。
        let mut files = Vec::new();
        for entry in fs::read_dir(&resolved).map_err(|error| format!("枚举目录失败: {error}"))?
        {
            check_active()?;
            let path = entry
                .map_err(|error| format!("枚举目录项失败: {error}"))?
                .path();
            let path = resolve_safe_path(path.to_str().ok_or("目录项路径不是有效UTF-8")?)?;
            if !fs::metadata(&path)
                .map_err(|error| format!("读取目录项状态失败: {error}"))?
                .is_file()
            {
                return Err("目录包含非普通文件，未读取或清理该目录".into());
            }
            files.push(path);
        }
        let mut contents = String::new();
        for (index, path) in files.iter().enumerate() {
            check_active()?;
            resolve_safe_path(path.to_str().ok_or("目录项路径不是有效UTF-8")?)?;
            let bytes = fs::read(path).map_err(|error| format!("读取目录文件失败: {error}"))?;
            if index != 0 {
                contents.push('\n');
            }
            contents.push_str(&decode_text(&bytes, None)?);
        }
        // 清理开始前最后一次观察取消；读取失败时以上流程不会删除任何文件。
        check_active()?;
        for path in &files {
            resolve_safe_path(path.to_str().ok_or("目录项路径不是有效UTF-8")?)?;
            fs::remove_file(path).map_err(|error| format!("清理已读取文件失败: {error}"))?;
        }
        // 非递归删除拒绝清除后来新增的未读取项；清理阶段IO失败不承诺原子回滚。
        fs::remove_dir(&canonical).map_err(|error| format!("清理已读取目录失败: {error}"))?;
        Ok(contents)
    }
}

#[cfg(feature = "quickjs")]
pub use impl_file_utils::*;

// ============================================================
// 未启用 quickjs feature 时的占位实现
// ============================================================
#[cfg(not(feature = "quickjs"))]
mod stub_file_utils {
    use std::path::PathBuf;

    fn not_available() -> String {
        "file_utils not available: build with --features quickjs".to_string()
    }

    pub fn default_sandbox_root() -> PathBuf {
        std::env::temp_dir().join("legado_js_cache")
    }
    pub fn sandbox_root() -> PathBuf {
        default_sandbox_root()
    }
    pub fn resolve_safe_path(_path: &str) -> Result<PathBuf, String> {
        Err(not_available())
    }
    pub fn read_file(_relative_path: &str) -> Result<String, String> {
        Err(not_available())
    }
    pub fn read_file_bytes(_relative_path: &str) -> Result<Option<Vec<u8>>, String> {
        Err(not_available())
    }
    pub fn write_file(_relative_path: &str, _content: &str) -> Result<(), String> {
        Err(not_available())
    }
    pub fn file_exists(_relative_path: &str) -> Result<bool, String> {
        Err(not_available())
    }
    pub fn delete_file(_relative_path: &str) -> Result<bool, String> {
        Err(not_available())
    }
    pub fn list_files(_relative_path: &str) -> Result<Vec<String>, String> {
        Err(not_available())
    }
    pub fn read_txt_file(_path: &str, _charset: Option<&str>) -> Result<String, String> {
        Err(not_available())
    }
    pub fn get_txt_in_folder(_folder_path: &str) -> Result<String, String> {
        Err(not_available())
    }
}

#[cfg(not(feature = "quickjs"))]
pub use stub_file_utils::*;

// ============================================================
// 单元测试
// ============================================================
#[cfg(all(test, feature = "quickjs"))]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;

    fn setup_sandbox() {
        let root = sandbox_root();
        let _ = fs::create_dir_all(&root);
    }

    fn cleanup_test_file(name: &str) {
        let path = sandbox_root().join(name);
        let _ = fs::remove_file(&path);
    }

    fn cleanup_test_dir(name: &str) {
        let path = sandbox_root().join(name);
        let _ = fs::remove_dir_all(&path);
    }

    // ---- 基本文件操作测试 ----

    #[test]
    fn test_write_and_read_file() {
        setup_sandbox();
        cleanup_test_file("test_rw.txt");
        write_file("test_rw.txt", "hello world").unwrap();
        let content = read_file("test_rw.txt").unwrap();
        assert_eq!(content, "hello world");
        cleanup_test_file("test_rw.txt");
    }

    #[test]
    fn test_file_exists_true() {
        setup_sandbox();
        cleanup_test_file("test_exists.txt");
        write_file("test_exists.txt", "data").unwrap();
        assert!(file_exists("test_exists.txt").unwrap());
        cleanup_test_file("test_exists.txt");
    }

    #[test]
    fn test_file_exists_false() {
        setup_sandbox();
        assert!(!file_exists("nonexistent_file_xyz.txt").unwrap());
    }

    #[test]
    fn test_delete_file() {
        setup_sandbox();
        cleanup_test_file("test_delete.txt");
        write_file("test_delete.txt", "to delete").unwrap();
        assert!(delete_file("test_delete.txt").unwrap());
        assert!(!file_exists("test_delete.txt").unwrap());
    }

    #[test]
    fn test_delete_nonexistent() {
        setup_sandbox();
        assert!(!delete_file("no_such_file_xyz.txt").unwrap());
    }

    #[test]
    fn test_read_nonexistent_returns_empty() {
        setup_sandbox();
        let content = read_file("no_such_file.txt").unwrap();
        assert_eq!(content, "");
    }

    #[test]
    fn test_list_files_empty_dir() {
        setup_sandbox();
        let root = sandbox_root();
        let empty_subdir = root.join("empty_test_dir");
        let _ = fs::create_dir_all(&empty_subdir);
        let files = list_files("empty_test_dir").unwrap();
        assert!(files.is_empty());
        let _ = fs::remove_dir(&empty_subdir);
    }

    // ---- 沙箱安全测试 ----

    #[test]
    fn test_sandbox_path_traversal_blocked() {
        setup_sandbox();
        // 尝试通过 .. 逃逸沙箱
        let result = resolve_safe_path("../../etc/passwd");
        assert!(result.is_err(), "路径穿越应被阻止, got: {:?}", result);
        let err_msg = result.unwrap_err();
        assert!(
            err_msg.contains("Path traversal blocked"),
            "错误信息应包含 'Path traversal blocked', got: {}",
            err_msg
        );
    }

    #[test]
    fn test_sandbox_path_traversal_read_blocked() {
        setup_sandbox();
        // 通过 read_file 尝试路径穿越
        let result = read_file("../../../etc/passwd");
        assert!(
            result.is_err() || result.as_deref() == Ok(""),
            "路径穿越读取应被阻止或返回空"
        );
    }

    #[test]
    fn test_sandbox_valid_path() {
        setup_sandbox();
        // 正常相对路径应解析到沙箱内
        let result = resolve_safe_path("subdir/file.txt");
        assert!(result.is_ok());
        let resolved = result.unwrap();
        let sandbox = default_sandbox_root();
        assert!(
            resolved.starts_with(&sandbox),
            "解析路径应在沙箱内: {:?}",
            resolved
        );
    }

    #[test]
    fn test_sandbox_absolute_path_outside_blocked() {
        setup_sandbox();
        // 沙箱外的绝对路径应被阻止（如果其 parent 存在）
        let outside = if cfg!(windows) {
            "C:\\Windows\\System32\\cmd.exe"
        } else {
            "/etc/passwd"
        };
        let result = resolve_safe_path(outside);
        // 绝对路径在沙箱外，parent 存在且不在沙箱内 → 应被阻止
        assert!(result.is_err(), "沙箱外绝对路径应被阻止, got: {:?}", result);
    }

    #[test]
    fn test_sandbox_nested_traversal_blocked() {
        setup_sandbox();
        // 嵌套路径穿越
        let result = resolve_safe_path("subdir/../../..");
        assert!(result.is_err(), "嵌套路径穿越应被阻止, got: {:?}", result);
    }

    #[test]
    fn archive_read_outside_path_is_rejected_even_with_missing_parents() {
        let outside = default_sandbox_root()
            .parent()
            .unwrap()
            .join(format!("outside_{}", uuid::Uuid::new_v4()))
            .join("missing/file");
        assert!(!outside.parent().unwrap().exists());
        assert!(resolve_safe_path(outside.to_str().unwrap()).is_err());
        assert!(!outside.parent().unwrap().exists());
    }

    #[cfg(unix)]
    #[test]
    fn archive_read_file_and_directory_symlinks_cannot_escape_sandbox() {
        let name = format!("links_{}", uuid::Uuid::new_v4());
        let inside = default_sandbox_root().join(&name);
        let outside = std::env::temp_dir().join(format!("outside_{name}"));
        fs::create_dir_all(&inside).unwrap();
        fs::create_dir_all(&outside).unwrap();
        fs::write(outside.join("secret"), "secret").unwrap();
        std::os::unix::fs::symlink(outside.join("secret"), inside.join("file")).unwrap();
        std::os::unix::fs::symlink(&outside, inside.join("directory")).unwrap();
        assert!(read_file_bytes(&format!("{name}/file")).is_err());
        assert!(write_file(&format!("{name}/directory/missing/file"), "bad").is_err());
        assert!(!outside.join("missing").exists());
        fs::remove_dir_all(inside).unwrap();
        fs::remove_dir_all(outside).unwrap();
    }

    // ---- readTxtFile 编码测试 ----

    #[test]
    fn test_read_txt_file_utf8() {
        setup_sandbox();
        cleanup_test_file("test_utf8.txt");
        let content = "你好世界 Hello World";
        write_file("test_utf8.txt", content).unwrap();

        let result = read_txt_file("test_utf8.txt", Some("utf-8")).unwrap();
        assert_eq!(result, content);

        // 默认编码也是 UTF-8
        let result_default = read_txt_file("test_utf8.txt", None).unwrap();
        assert_eq!(result_default, content);
        cleanup_test_file("test_utf8.txt");
    }

    #[test]
    fn test_read_txt_file_gbk() {
        setup_sandbox();
        cleanup_test_file("test_gbk.txt");

        // 用 GBK 编码写入中文
        let text = "你好世界";
        let (encoded, _enc, _err) = encoding_rs::GBK.encode(text);
        let sandbox = default_sandbox_root();
        let file_path = sandbox.join("test_gbk.txt");
        fs::write(&file_path, &encoded[..]).unwrap();

        // 用 GBK 编码读取
        let result = read_txt_file("test_gbk.txt", Some("gbk")).unwrap();
        assert_eq!(result, text);
        cleanup_test_file("test_gbk.txt");
    }

    #[test]
    fn test_read_txt_file_nonexistent() {
        setup_sandbox();
        let result = read_txt_file("no_such_file.txt", None).unwrap();
        assert_eq!(result, "");
    }

    // ---- 文件操作综合测试 ----

    #[test]
    fn test_file_operations_in_sandbox() {
        setup_sandbox();
        let test_dir = "test_ops_dir";
        cleanup_test_dir(test_dir);

        // 写入子目录文件
        write_file("test_ops_dir/a.txt", "file a").unwrap();
        write_file("test_ops_dir/b.txt", "file b").unwrap();
        write_file("test_ops_dir/c.log", "log c").unwrap();

        // 验证文件存在
        assert!(file_exists("test_ops_dir/a.txt").unwrap());
        assert!(file_exists("test_ops_dir/b.txt").unwrap());

        // 列出目录
        let files = list_files(test_dir).unwrap();
        assert_eq!(files.len(), 3);

        // 普通单文件删除保持原行为。
        assert!(delete_file("test_ops_dir/a.txt").unwrap());
        assert!(!file_exists("test_ops_dir/a.txt").unwrap());

        // 目录读取包含全部直接文件，成功后清理目录。
        let txt_content = get_txt_in_folder(test_dir).unwrap();
        assert!(txt_content.contains("file b"));
        assert!(txt_content.contains("log c"));
        assert!(!file_exists(test_dir).unwrap());

        // 清理
        cleanup_test_dir(test_dir);
    }

    #[test]
    fn test_get_txt_in_folder_nonexistent() {
        setup_sandbox();
        let result = get_txt_in_folder("nonexistent_folder_xyz");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Folder not found"));
    }

    #[test]
    fn test_get_txt_in_folder_not_a_dir() {
        setup_sandbox();
        cleanup_test_file("not_a_dir.txt");
        write_file("not_a_dir.txt", "content").unwrap();
        let result = get_txt_in_folder("not_a_dir.txt");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Not a directory"));
        cleanup_test_file("not_a_dir.txt");
    }

    // 每个用例只持有随机命名的子目录，结束时清理本用例遗留。
    struct FolderFixture(PathBuf);
    impl FolderFixture {
        fn new() -> Self {
            let path = default_sandbox_root().join(format!("folder_text_{}", uuid::Uuid::new_v4()));
            fs::create_dir_all(&path).unwrap();
            Self(path)
        }
        fn path(&self) -> &str {
            self.0.to_str().unwrap()
        }
    }
    impl Drop for FolderFixture {
        fn drop(&mut self) {
            assert!(self.0.starts_with(default_sandbox_root()));
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn folder_text_reads_all_extensions_in_enumeration_order_and_cleans_after_success() {
        use std::collections::HashMap;
        let folder = FolderFixture::new();
        let expected = HashMap::from([
            ("a.txt", "UTF-8正文"),
            ("b.log", "中文内容，自动识别编码。"),
            ("no_extension", "带BOM的正文"),
            ("empty.bin", ""),
        ]);
        fs::write(folder.0.join("a.txt"), expected["a.txt"]).unwrap();
        let (gbk, _, _) = encoding_rs::GBK.encode(expected["b.log"]);
        fs::write(folder.0.join("b.log"), gbk).unwrap();
        let utf16: Vec<u8> = [0xff, 0xfe]
            .into_iter()
            .chain(
                expected["no_extension"]
                    .encode_utf16()
                    .flat_map(u16::to_le_bytes),
            )
            .collect();
        fs::write(folder.0.join("no_extension"), utf16).unwrap();
        fs::write(folder.0.join("empty.bin"), []).unwrap();
        let contents: Vec<_> = fs::read_dir(&folder.0)
            .unwrap()
            .map(|entry| expected[entry.unwrap().file_name().to_str().unwrap()])
            .collect();
        assert_eq!(
            get_txt_in_folder(folder.path()).unwrap(),
            contents.join("\n")
        );
        assert!(!folder.0.exists(), "完整读取后清理指定子目录");
    }

    #[test]
    fn folder_text_empty_directory_is_an_empty_result_and_is_cleaned() {
        let folder = FolderFixture::new();
        assert_eq!(get_txt_in_folder(folder.path()).unwrap(), "");
        assert!(!folder.0.exists());
    }

    #[test]
    fn folder_text_empty_path_is_noop_and_root_aliases_are_rejected() {
        let marker = FolderFixture::new();
        fs::write(marker.0.join("keep"), "保留").unwrap();
        assert_eq!(get_txt_in_folder("").unwrap(), "");
        for path in [
            PathBuf::from("."),
            default_sandbox_root(),
            default_sandbox_root().join("."),
        ] {
            assert!(
                get_txt_in_folder(path.to_str().unwrap()).is_err(),
                "根目录必须拒绝: {path:?}"
            );
        }
        assert_eq!(fs::read_to_string(marker.0.join("keep")).unwrap(), "保留");
    }

    #[test]
    fn folder_text_non_file_entry_aborts_without_deleting_any_input() {
        let folder = FolderFixture::new();
        fs::write(folder.0.join("readme.txt"), "不得删除").unwrap();
        fs::create_dir(folder.0.join("nested")).unwrap();
        fs::write(folder.0.join("nested/keep"), "嵌套内容").unwrap();
        assert!(get_txt_in_folder(folder.path()).is_err());
        assert_eq!(
            fs::read_to_string(folder.0.join("readme.txt")).unwrap(),
            "不得删除"
        );
        assert_eq!(
            fs::read_to_string(folder.0.join("nested/keep")).unwrap(),
            "嵌套内容"
        );
    }

    #[test]
    fn folder_text_dual_js_entries_throw_on_failure_and_keep_vm_usable() {
        use crate::{JsEngine, QuickJsEngine, SandboxConfig};
        let vm = QuickJsEngine::new(SandboxConfig::permissive()).unwrap();
        for call in ["getTxtInFolder", "java.getTxtInFolder"] {
            let folder = FolderFixture::new();
            fs::write(folder.0.join("body.log"), "正文").unwrap();
            let path = serde_json::to_string(folder.path()).unwrap();
            assert_eq!(vm.eval(&format!("{call}({path})")).unwrap(), "正文");
            assert!(!folder.0.exists());
            assert_eq!(
                vm.eval(&format!(
                    "try {{{call}({path}); 'bad'}} catch(e) {{'caught'}}"
                ))
                .unwrap(),
                "caught"
            );
            assert_eq!(vm.eval("1+1").unwrap(), "2");
        }
        let strict = QuickJsEngine::new(SandboxConfig::default()).unwrap();
        assert_eq!(
            strict
                .eval("typeof java.getTxtInFolder + ':' + typeof getTxtInFolder")
                .unwrap(),
            "undefined:undefined"
        );
    }

    #[test]
    fn folder_text_observed_cancellation_preserves_inputs() {
        struct Cancelled;
        impl crate::cancellation::JsCancellation for Cancelled {
            fn is_cancelled(&self) -> bool {
                true
            }
            fn cancelled(&self) -> crate::cancellation::CancelWait<'_> {
                Box::pin(async {})
            }
        }
        let folder = FolderFixture::new();
        fs::write(folder.0.join("body.txt"), "保留").unwrap();
        let _scope = crate::cancellation::Scope::enter(Some(std::sync::Arc::new(Cancelled)));
        let error = get_txt_in_folder(folder.path()).expect_err("取消不能消费目录");
        assert!(error.contains(crate::cancellation::CANCELLED));
        assert_eq!(
            fs::read_to_string(folder.0.join("body.txt")).unwrap(),
            "保留"
        );
    }

    #[cfg(windows)]
    #[test]
    fn folder_text_read_failure_preserves_all_files() {
        use std::os::windows::fs::OpenOptionsExt;
        let folder = FolderFixture::new();
        fs::write(folder.0.join("readable.txt"), "保留可读内容").unwrap();
        let locked = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .share_mode(0)
            .open(folder.0.join("locked.log"))
            .unwrap();
        assert!(
            get_txt_in_folder(folder.path()).is_err(),
            "共享锁导致的读取失败不得静默跳过"
        );
        assert_eq!(
            fs::read_to_string(folder.0.join("readable.txt")).unwrap(),
            "保留可读内容"
        );
        drop(locked);
        assert!(folder.0.join("locked.log").exists());
    }

    #[test]
    fn folder_text_dot_suffix_is_allowed_for_a_real_directory() {
        let folder = FolderFixture::new();
        fs::write(folder.0.join("keep.txt"), "正常目录正文").unwrap();
        let dotted = folder.0.join(".");
        assert_eq!(
            get_txt_in_folder(dotted.to_str().unwrap()).unwrap(),
            "正常目录正文"
        );
        assert!(!folder.0.exists());
    }

    #[cfg(any(unix, windows))]
    #[test]
    #[cfg_attr(windows, ignore = "需要Windows符号链接权限，在具备权限的环境单独复验")]
    fn folder_text_external_links_and_root_link_aliases_cannot_be_consumed() {
        #[cfg(unix)]
        use std::os::unix::fs::{symlink as symlink_file, symlink as symlink_dir};
        #[cfg(windows)]
        use std::os::windows::fs::{symlink_dir, symlink_file};
        let folder = FolderFixture::new();
        let outside =
            std::env::temp_dir().join(format!("outside_folder_text_{}", uuid::Uuid::new_v4()));
        fs::write(&outside, "外部数据").unwrap();
        fs::write(folder.0.join("readable.txt"), "保留").unwrap();
        symlink_file(&outside, folder.0.join("escape.txt")).unwrap();
        assert!(get_txt_in_folder(folder.path()).is_err());
        assert_eq!(fs::read_to_string(&outside).unwrap(), "外部数据");
        assert!(folder.0.join("readable.txt").exists());
        let alias = folder.0.join("root_alias");
        symlink_dir(default_sandbox_root(), &alias).unwrap();
        assert!(get_txt_in_folder(alias.to_str().unwrap()).is_err());
        let target = FolderFixture::new();
        fs::write(target.0.join("keep"), "链接目标保留").unwrap();
        let link = folder.0.join("other_alias");
        symlink_dir(&target.0, &link).unwrap();
        for path in [link.clone(), link.join("."), link.join(".").join(".")] {
            assert!(
                get_txt_in_folder(path.to_str().unwrap()).is_err(),
                "目录别名不得被消费: {}",
                path.display()
            );
        }
        assert!(target.0.join("keep").exists());
        // 单独建立子目录，避免它作为非普通文件提前拒绝、掩盖上面的link/.回归。
        let nested = target.0.join("nested");
        fs::create_dir(&nested).unwrap();
        fs::write(nested.join("keep"), "子目录链接目标保留").unwrap();
        for path in [link.join("nested"), link.join("nested").join(".")] {
            assert!(get_txt_in_folder(path.to_str().unwrap()).is_err());
        }
        assert!(nested.join("keep").exists());
        fs::remove_file(outside).unwrap();
    }

    #[cfg(windows)]
    #[test]
    fn folder_text_cleanup_failure_is_visible_and_does_not_report_success() {
        use std::os::windows::fs::OpenOptionsExt;
        let folder = FolderFixture::new();
        fs::write(folder.0.join("readable.txt"), "可以读取，暂不可删除").unwrap();
        let held = fs::OpenOptions::new()
            .read(true)
            .share_mode(1)
            .open(folder.0.join("readable.txt"))
            .unwrap();
        assert_eq!(
            fs::read_to_string(folder.0.join("readable.txt")).unwrap(),
            "可以读取，暂不可删除"
        );
        let error = get_txt_in_folder(folder.path()).expect_err("清理失败不能返回成功内容");
        assert!(error.contains("清理已读取文件失败"), "{error}");
        drop(held);
        assert_eq!(
            fs::read_to_string(folder.0.join("readable.txt")).unwrap(),
            "可以读取，暂不可删除"
        );
    }
}
