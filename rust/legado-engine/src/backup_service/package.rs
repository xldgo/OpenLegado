//! 本地、WebDAV共用的备份包；仅按清单读取成员，不解压到任意输入路径。
use super::*;
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use std::collections::{BTreeMap, BTreeSet};
use std::io::{Cursor, Read, Write};
use zip::{ZipArchive, ZipWriter, write::SimpleFileOptions};

const MAX_ENTRY: u64 = 64 * 1024 * 1024;
const MAX_PACKAGE: u64 = 256 * 1024 * 1024;
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Manifest {
    format: String,
    version: i32,
    backup_time: i64,
    config: BTreeMap<String, String>,
    collections: Vec<String>,
    preferences: Map<String, Value>,
    sensitive: Map<String, Value>,
    resources: BTreeMap<String, String>,
}
pub(super) struct Decoded {
    pub data: BackupData,
    pub preferences: Map<String, Value>,
    pub sensitive: Map<String, Value>,
    pub files: BTreeMap<String, Vec<u8>>,
    pub resources: BTreeMap<String, String>,
    pub warnings: Vec<String>,
}
fn invalid(message: impl Into<String>) -> LegadoError {
    LegadoError::Parser(message.into())
}
fn zip_error(error: impl std::fmt::Display) -> LegadoError {
    invalid(format!("备份ZIP错误: {error}"))
}
fn add(writer: &mut ZipWriter<Cursor<Vec<u8>>>, name: &str, bytes: &[u8]) -> LegadoResult<()> {
    if bytes.len() as u64 > MAX_ENTRY {
        return Err(invalid(format!("备份成员{name}超过64MiB限额")));
    }
    writer
        .start_file(
            name,
            SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated),
        )
        .map_err(zip_error)?;
    writer.write_all(bytes)?;
    Ok(())
}
fn extension(path: &str) -> String {
    Path::new(path)
        .extension()
        .and_then(|s| s.to_str())
        .filter(|s| s.len() <= 8 && s.bytes().all(|b| b.is_ascii_alphanumeric()))
        .unwrap_or("bin")
        .into()
}
pub(super) fn encode(data: &BackupData, options: &BackupOptions) -> LegadoResult<Vec<u8>> {
    if !options.sensitive.is_empty() && options.password.as_deref().is_none_or(str::is_empty) {
        return Err(invalid("备份敏感信息前必须设置本地密码"));
    }
    let mut writer = ZipWriter::new(Cursor::new(Vec::new()));
    let mut resources = BTreeMap::new();
    let mut total = 0u64;
    let mut selected = options.files.clone();
    for (collection, field) in [("books", "customCoverUrl"), ("bookGroups", "cover")] {
        for row in &data.collections[collection] {
            if let Some(path) = row
                .get(field)
                .and_then(Value::as_str)
                .filter(|s| Path::new(s).is_absolute())
            {
                selected.insert(path.into(), path.into());
            }
        }
    }
    for (index, (original, path)) in selected.iter().enumerate() {
        let file = fs::File::open(path)?;
        let mut content = Vec::new();
        file.take(MAX_ENTRY + 1).read_to_end(&mut content)?;
        total += content.len() as u64;
        if total > MAX_PACKAGE {
            return Err(invalid("备份资源超过256MiB限额"));
        }
        let name = format!("resources/{index}.{}", extension(path));
        add(&mut writer, &name, &content)?;
        resources.insert(original.clone(), name);
    }
    for (name, rows) in &data.collections {
        let bytes = serde_json::to_vec(rows)?;
        total += bytes.len() as u64;
        if total > MAX_PACKAGE {
            return Err(invalid("备份内容超过256MiB限额"));
        }
        add(&mut writer, &format!("collections/{name}.json"), &bytes)?;
    }
    let manifest = Manifest {
        format: "openlegado".into(),
        version: 1,
        backup_time: data.backup_time,
        config: data.config.clone(),
        collections: data.collections.keys().cloned().collect(),
        preferences: options.preferences.clone(),
        sensitive: options.sensitive.clone(),
        resources,
    };
    add(
        &mut writer,
        "manifest.json",
        &serde_json::to_vec(&manifest)?,
    )?;
    let bytes = writer.finish().map_err(zip_error)?.into_inner();
    if bytes.len() as u64 > MAX_PACKAGE {
        return Err(invalid("备份包超过256MiB限额"));
    }
    super::crypto::seal(bytes, options.password.as_deref())
}
pub(super) fn decode(path: &str, password: Option<&str>) -> LegadoResult<Decoded> {
    let file = fs::File::open(path)?;
    if file.metadata()?.len() > MAX_PACKAGE {
        return Err(invalid("备份包超过256MiB限额"));
    }
    let mut bytes = Vec::new();
    file.take(MAX_PACKAGE + 1).read_to_end(&mut bytes)?;
    let sealed = super::crypto::is_sealed(&bytes);
    let bytes = super::crypto::open(bytes, password)?;
    let mut archive = ZipArchive::new(Cursor::new(bytes)).map_err(zip_error)?;
    if archive.len() > 4096 {
        return Err(invalid("备份成员数量超出限额"));
    }
    let mut files = BTreeMap::new();
    let mut total = 0;
    for index in 0..archive.len() {
        let mut file = archive.by_index(index).map_err(zip_error)?;
        let name = file.name().map_err(zip_error)?.into_owned();
        let normalized = name.trim_end_matches('/');
        if normalized.is_empty()
            || name.contains('\\')
            || name.contains(':')
            || normalized
                .split('/')
                .any(|part| part.is_empty() || part == "." || part == "..")
        {
            return Err(invalid("备份ZIP包含不安全路径"));
        }
        if file.is_dir() {
            continue;
        }
        if files.contains_key(&name) {
            return Err(invalid(format!("备份ZIP存在重复成员{name}")));
        }
        if file.size() > MAX_ENTRY {
            return Err(invalid(format!("备份成员{name}超过64MiB限额")));
        }
        let mut content = Vec::new();
        Read::by_ref(&mut file)
            .take(MAX_ENTRY + 1)
            .read_to_end(&mut content)?;
        total += content.len() as u64;
        if content.len() as u64 > MAX_ENTRY || total > MAX_PACKAGE {
            return Err(invalid("备份解压内容超过限额"));
        }
        files.insert(name, content);
    }
    let Some(raw) = files.remove("manifest.json") else {
        return super::upstream::decode(files, password);
    };
    let manifest: Manifest = serde_json::from_slice(&raw).map_err(zip_error)?;
    if manifest.format != "openlegado" || manifest.version != 1 {
        return Err(invalid("备份包格式或版本不受支持"));
    }
    if !sealed && !manifest.sensitive.is_empty() {
        return Err(invalid("未加密的备份包不能携带敏感凭据"));
    }
    let mut collections = BTreeMap::new();
    for key in manifest.collections {
        if !legado_db::backup::TABLES
            .iter()
            .any(|(name, _)| *name == key)
            || collections.contains_key(&key)
        {
            return Err(invalid("备份集合清单无效"));
        }
        let bytes = files
            .remove(&format!("collections/{key}.json"))
            .ok_or_else(|| invalid(format!("备份缺少集合{key}")))?;
        collections.insert(key, serde_json::from_slice(&bytes).map_err(zip_error)?);
    }
    let allowed = manifest.resources.values().collect::<BTreeSet<_>>();
    if files.keys().any(|name| !allowed.contains(name))
        || allowed.len() != files.len()
        || allowed.iter().any(|name| !files.contains_key(*name))
    {
        return Err(invalid("备份资源与清单不一致"));
    }
    for name in &allowed {
        if !name.starts_with("resources/") || name.split('/').count() != 2 {
            return Err(invalid("备份资源路径无效"));
        }
    }
    Ok(Decoded {
        data: BackupData {
            format: "openlegado".into(),
            version: 2,
            backup_time: manifest.backup_time,
            collections,
            config: manifest.config,
        },
        preferences: manifest.preferences,
        sensitive: manifest.sensitive,
        files,
        resources: manifest.resources,
        warnings: Vec::new(),
    })
}
// 只替换确切文件引用；StringList字体的family|path及嵌套JSON配置也保持原编码形式。
fn rewrite(value: &mut Value, paths: &BTreeMap<String, String>) -> bool {
    match value {
        Value::String(text) => {
            if let Some(path) = paths.get(text) {
                *text = path.clone();
                return true;
            }
            if let Some((family, path)) = text.split_once('|')
                && let Some(new) = paths.get(path)
            {
                *text = format!("{family}|{new}");
                return true;
            }
            if let Ok(mut parsed @ (Value::Array(_) | Value::Object(_))) =
                serde_json::from_str::<Value>(text)
                && rewrite(&mut parsed, paths)
            {
                *text = parsed.to_string();
                return true;
            }
            false
        }
        Value::Array(items) => {
            let mut changed = false;
            for item in items {
                changed |= rewrite(item, paths);
            }
            changed
        }
        Value::Object(items) => {
            let mut changed = false;
            for item in items.values_mut() {
                changed |= rewrite(item, paths);
            }
            changed
        }
        _ => false,
    }
}
pub(super) struct Resources {
    created: Vec<std::path::PathBuf>,
    committed: bool,
}
impl Drop for Resources {
    fn drop(&mut self) {
        if !self.committed {
            for path in &self.created {
                let _ = fs::remove_file(path);
            }
        }
    }
}
impl Resources {
    pub fn commit(mut self) {
        self.committed = true;
    }
}
pub(super) fn restore_resources(decoded: &mut Decoded, root: &Path) -> LegadoResult<Resources> {
    let mut guard = Resources {
        created: Vec::new(),
        committed: false,
    };
    let mut paths = BTreeMap::new();
    if !decoded.resources.is_empty() {
        fs::create_dir_all(root)?;
    }
    for (original, name) in &decoded.resources {
        let bytes = decoded
            .files
            .get(name)
            .ok_or_else(|| invalid("备份资源缺失"))?;
        let hash = ring::digest::digest(&ring::digest::SHA256, bytes)
            .as_ref()
            .iter()
            .map(|v| format!("{v:02x}"))
            .collect::<String>();
        let path = root.join(format!("{hash}.{}", extension(name)));
        match fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
        {
            Ok(mut file) => {
                guard.created.push(path.clone());
                file.write_all(bytes)?;
                file.sync_all()?;
            }
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
                if fs::read(&path)? != *bytes {
                    return Err(invalid("已恢复资源文件损坏，请检查应用资源目录"));
                }
            }
            Err(e) => return Err(e.into()),
        }
        paths.insert(original.clone(), path.to_string_lossy().into_owned());
    }
    let mut preferences = Value::Object(std::mem::take(&mut decoded.preferences));
    rewrite(&mut preferences, &paths);
    decoded.preferences = preferences.as_object().cloned().unwrap_or_default();
    for (collection, field) in [("books", "customCoverUrl"), ("bookGroups", "cover")] {
        if let Some(rows) = decoded.data.collections.get_mut(collection) {
            for row in rows {
                if let Some(value) = row.get_mut(field) {
                    rewrite(value, &paths);
                }
            }
        }
    }
    Ok(guard)
}
pub(super) fn write_atomic(path: &str, bytes: &[u8]) -> LegadoResult<()> {
    let target = Path::new(path);
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)?;
    }
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    let temporary = target.with_extension(format!("{stamp}.tmp"));
    let mut file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&temporary)?;
    let result = (|| {
        file.write_all(bytes)?;
        file.sync_all()?;
        drop(file);
        fs::rename(&temporary, target)?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result
}
