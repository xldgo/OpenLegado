//! 档案来源、条目与脚本返回值转换；文字与字节接口共用一次读取路径。
//! — Codex + Bridge
use super::{archive_utils, rule_request};
use crate::http_resources::HttpResources;

#[derive(Clone, Copy)]
pub(super) enum ArchiveKind {
    Zip,
    SevenZip,
}

pub(super) fn read_entry(
    ctx: &rquickjs::Ctx<'_>,
    http: &HttpResources,
    source: &str,
    entry: &str,
    kind: ArchiveKind,
    allow_file_access: bool,
) -> Result<Option<Vec<u8>>, String> {
    http.request()
        .check_active()
        .map_err(|error| error.to_string())?;
    let bytes = if ["http://", "https://", "data:", "@js:", "<js>", "{{"]
        .iter()
        .any(|prefix| source.trim_start().starts_with(prefix))
    {
        let evaluator =
            rule_request::ContextEvaluator::new(ctx.clone()).map_err(|error| error.to_string())?;
        rule_request::execute_bytes(&http.request(), source, &evaluator)?
    } else if allow_file_access && std::path::Path::new(source).exists() {
        // 保留已有本地档案路径扩展，受文件访问开关控制。
        std::fs::read(source).map_err(|error| format!("读取本地档案失败: {error}"))?
    } else {
        hex::decode(source).map_err(|_| {
            "输入不是有效档案十六进制数据，或本地文件不存在/未获文件访问授权".to_string()
        })?
    };
    http.request()
        .check_active()
        .map_err(|error| error.to_string())?;
    match kind {
        ArchiveKind::Zip => archive_utils::zip_entry_bytes_optional(&bytes, entry),
        ArchiveKind::SevenZip => archive_utils::seven_z_entry_bytes_optional(&bytes, entry),
    }
}

pub(super) fn bytes_to_js<'js>(
    ctx: &rquickjs::Ctx<'js>,
    bytes: Option<Vec<u8>>,
) -> rquickjs::Result<rquickjs::Value<'js>> {
    use rquickjs::IntoJs;
    match bytes {
        Some(bytes) => rquickjs::TypedArray::<u8>::new(ctx.clone(), bytes)?.into_js(ctx),
        None => Ok(rquickjs::Value::new_null(ctx.clone())),
    }
}
