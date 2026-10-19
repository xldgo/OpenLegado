//! 规则下载与文本缓存；当前VM只用于准备请求，文件协调锁不跨JS求值。
use super::{cache_store::CacheStore, encoding, file_utils, rule_request};
use crate::http_resources::HttpResources;
use std::path::{Path, PathBuf};

fn prepare(
    ctx: &rquickjs::Ctx<'_>,
    http: &HttpResources,
    input: &str,
) -> Result<rule_request::PreparedRequest, String> {
    let evaluator = rule_request::ContextEvaluator::new(ctx.clone()).map_err(|e| e.to_string())?;
    rule_request::prepare(&http.request(), input, Default::default(), Some(&evaluator))
}

/// URL后缀沿用上游限定：去掉查询/片段，最长5位ASCII字母数字，无合法后缀为ext。
fn suffix(input: &str) -> &str {
    let url = input
        .match_indices(',')
        .find(|(index, _)| input[index + 1..].trim_start().starts_with('{'))
        .map_or(input, |(index, _)| &input[..index]);
    let last = url.rsplit('/').next().unwrap_or(url);
    let path = last.split(['?', '#']).next().unwrap_or(last);
    match path.rsplit_once('.') {
        Some((_, ext))
            if !ext.is_empty()
                && ext.len() <= 5
                && ext.bytes().all(|b| b.is_ascii_alphanumeric()) =>
        {
            ext
        }
        _ => "ext",
    }
}

fn file_name(key: &str, extension: &str) -> Result<String, String> {
    // type是外部规则数据，不允许改变目录或在Windows上创建ADS。
    if extension.contains(['/', '\\', ':', '\0']) || extension.contains("..") {
        return Err("下载文件类型包含不安全的路径字符".into());
    }
    Ok(format!("{key}.{extension}"))
}

fn relative(path: &Path) -> Result<String, String> {
    path.strip_prefix(file_utils::default_sandbox_root())
        .map(|path| path.to_string_lossy().replace('\\', "/"))
        .map_err(|_| "下载路径不在脚本沙箱内".into())
}

fn publish(http: &HttpResources, name: &str, bytes: &[u8]) -> Result<PathBuf, String> {
    http.request().check_active().map_err(|e| e.to_string())?;
    let directory = http.file_cache_dir()?;
    // 除目标外也验证临时文件，拒绝已有链接指向沙箱外。
    file_utils::resolve_safe_path(&directory.join(name).to_string_lossy())?;
    file_utils::resolve_safe_path(&directory.join(format!("{name}.part")).to_string_lossy())?;
    let path = http.publish_file_cache(name, bytes)?;
    if let Err(error) = http.request().check_active() {
        let _ = std::fs::remove_file(&path);
        return Err(error.to_string());
    }
    Ok(path)
}

pub(super) fn download(
    ctx: &rquickjs::Ctx<'_>,
    http: &HttpResources,
    input: &str,
    hex_content: Option<&str>,
) -> Result<String, String> {
    let prepared = prepare(ctx, http, input)?;
    let extension = match (prepared.file_type(), hex_content) {
        (Some(extension), _) => extension,
        (None, Some(_)) => return Ok(String::new()),
        (None, None) => suffix(input),
    };
    let key = encoding::md5_encode_16(input);
    let name = file_name(&key, extension)?;
    // 请求和规则求值在锁外；同名文件只在短暂发布阶段协调。
    let bytes = match hex_content {
        Some(hex) => hex::decode(hex).map_err(|_| "下载内容不是有效十六进制数据".to_string())?,
        None => rule_request::execute_prepared_bytes(&http.request(), &prepared)?,
    };
    http.with_file_cache(&key, || relative(&publish(http, &name, &bytes)?))
}

fn cached_text(
    http: &HttpResources,
    cache: &CacheStore,
    key: &str,
) -> Result<Option<String>, String> {
    let Some(relative) = cache.get(key, false) else {
        return Ok(None);
    };
    let Ok(path) = file_utils::resolve_safe_path(&relative) else {
        return Ok(None);
    };
    // 即使配置了共享普通缓存，也不读取另一个HttpResources拥有的自动文件。
    if path.parent() != Some(http.file_cache_dir()?.as_path()) || !path.is_file() {
        return Ok(None);
    }
    let text = file_utils::read_txt_file(&relative, None)?;
    http.request().check_active().map_err(|e| e.to_string())?;
    Ok(Some(text))
}

pub(super) fn cache_text(
    ctx: &rquickjs::Ctx<'_>,
    http: &HttpResources,
    cache: &CacheStore,
    input: &str,
    save_time: i32,
) -> Result<String, String> {
    http.request().check_active().map_err(|e| e.to_string())?;
    let key = encoding::md5_encode_16(input);
    if let Some(text) = cached_text(http, cache, &key)? {
        return Ok(text);
    }
    let prepared = prepare(ctx, http, input)?;
    let name = file_name(&key, prepared.file_type().unwrap_or_else(|| suffix(input)))?;
    let bytes = rule_request::execute_prepared_bytes(&http.request(), &prepared)?;
    http.with_file_cache(&key, || {
        http.request().check_active().map_err(|e| e.to_string())?;
        // 另一调用可能已下载完成，重新检查；命中不刷新截止时间。
        if let Some(text) = cached_text(http, cache, &key)? {
            return Ok(text);
        }
        let path = relative(&publish(http, &name, &bytes)?)?;
        let text = file_utils::read_txt_file(&path, None)?;
        http.request().check_active().map_err(|e| e.to_string())?;
        cache.put(&key, &path, i64::from(save_time));
        Ok(text)
    })
}

pub(super) fn import(
    ctx: &rquickjs::Ctx<'_>,
    http: &HttpResources,
    cache: &CacheStore,
    path: &str,
) -> Result<String, String> {
    http.request().check_active().map_err(|e| e.to_string())?;
    let text = if path.starts_with("http") {
        cache_text(ctx, http, cache, path, 0)?
    } else {
        file_utils::read_txt_file(path, None)?
    };
    if text.trim().is_empty() {
        return Err("脚本内容获取失败或者为空".into());
    }
    Ok(text)
}
