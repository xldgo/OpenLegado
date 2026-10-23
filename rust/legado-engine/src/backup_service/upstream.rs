//! 原版/参考版ZIP显式适配；Android偏好只接入已核对的WebDAV连接。
use super::package::Decoded;
use legado_core::{LegadoError, LegadoResult};
use serde_json::{Map, Value};
use std::collections::BTreeMap;
fn invalid() -> LegadoError {
    LegadoError::Parser("原版备份连接设置格式无效".into())
}
fn preferences(raw: &[u8]) -> LegadoResult<BTreeMap<String, String>> {
    use quick_xml::{Reader, events::Event};
    let text = std::str::from_utf8(raw).map_err(|_| invalid())?;
    let mut reader = Reader::from_str(text);
    let mut values = BTreeMap::new();
    let mut depth = 0;
    let mut root = false;
    loop {
        match reader.read_event().map_err(|_| invalid())? {
            Event::Start(e) if depth == 0 => {
                if root || e.name().as_ref() != "map" {
                    return Err(invalid());
                }
                root = true;
                depth = 1;
            }
            Event::Start(e) if depth == 1 && e.name().as_ref() == "string" => {
                let name = e
                    .try_get_attribute("name")
                    .map_err(|_| invalid())?
                    .ok_or_else(invalid)?
                    .normalized_value(quick_xml::XmlVersion::Explicit1_0)
                    .map_err(|_| invalid())?
                    .into_owned();
                let raw = reader.read_text(e.name()).map_err(|_| invalid())?;
                let value = quick_xml::escape::unescape(raw.as_ref())
                    .map_err(|_| invalid())?
                    .into_owned();
                if values.insert(name, value).is_some() {
                    return Err(invalid());
                }
            }
            Event::Start(_) => depth += 1,
            Event::End(_) => {
                if depth == 0 {
                    return Err(invalid());
                }
                depth -= 1;
            }
            Event::DocType(_) => return Err(invalid()),
            Event::Eof => {
                if !root || depth != 0 {
                    return Err(invalid());
                }
                break;
            }
            _ => {}
        }
    }
    Ok(values)
}
pub(super) fn decode(
    mut files: BTreeMap<String, Vec<u8>>,
    password: Option<&str>,
) -> LegadoResult<Decoded> {
    let config = files.remove("config.xml");
    let (data, mut warnings) = if files.is_empty() && config.is_some() {
        let memory = legado_db::init_in_memory_database()?;
        (
            legado_db::backup::BackupRepository::new(memory.connection()).export(0)?,
            Vec::new(),
        )
    } else {
        legado_db::backup::from_upstream(&files)?
    };
    let mut prefs = Map::new();
    let mut sensitive = Map::new();
    if let Some(raw) = config {
        let mut values = preferences(&raw)?;
        for (old, new) in [
            ("web_dav_url", "sync_webdav_url"),
            ("web_dav_account", "sync_webdav_username"),
            ("webDavDir", "sync_webdav_remote_dir"),
        ] {
            if let Some(value) = values.remove(old) {
                prefs.insert(new.into(), Value::String(value));
            }
        }
        if let Some(encrypted) = values.remove("web_dav_password").filter(|s| !s.is_empty()) {
            use base64::Engine;
            let key = legado_core::crypto::md5_hex(password.unwrap_or(""));
            let decoded = base64::engine::general_purpose::STANDARD
                .decode(&encrypted)
                .map_err(|_| LegadoError::Parser("原版备份密码内容无效".into()))?;
            let clear =
                legado_core::crypto::AesCrypto::decrypt_ecb(&key.as_bytes()[..16], &decoded)
                    .map_err(|_| LegadoError::Parser("原版备份密码错误或连接凭据已损坏".into()))?;
            let clear = String::from_utf8(clear)
                .map_err(|_| LegadoError::Parser("原版备份密码错误或连接凭据已损坏".into()))?;
            sensitive.insert("webDavPassword".into(), Value::String(clear));
        }
        warnings.push("config.xml仅恢复WebDAV连接，其余Android设置未映射".into());
    }
    Ok(Decoded {
        data,
        preferences: prefs,
        sensitive,
        files: Default::default(),
        resources: Default::default(),
        warnings,
    })
}
