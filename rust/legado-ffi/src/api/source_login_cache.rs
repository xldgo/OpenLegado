//! 书源登录头 / 用户信息缓存（对标 Android `CacheManager` loginHeader_ / userInfo_）

use legado_core::LegadoResult;

pub fn get_login_header(source_url: &str) -> Option<String> {
    crate::engine_holder::source_login_cache().get_login_header(source_url)
}

pub fn put_login_header(source_url: &str, header: &str) -> LegadoResult<()> {
    crate::engine_holder::source_login_cache().put_login_header(source_url, header);
    Ok(())
}

pub fn remove_login_header(source_url: &str) -> LegadoResult<()> {
    crate::engine_holder::source_login_cache().remove_login_header(source_url);
    Ok(())
}

pub fn get_login_info(source_url: &str) -> Option<String> {
    crate::engine_holder::source_login_cache().get_login_info(source_url)
}

pub fn put_login_info(source_url: &str, info: &str) -> LegadoResult<()> {
    crate::engine_holder::source_login_cache().put_login_info(source_url, info);
    Ok(())
}

pub fn remove_login_info(source_url: &str) -> LegadoResult<()> {
    crate::engine_holder::source_login_cache().remove_login_info(source_url);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_login_header_roundtrip() {
        let url = "https://login-cache.test";
        put_login_header(url, r#"{"Authorization":"Bearer t"}"#).unwrap();
        let got = get_login_header(url).unwrap();
        assert!(got.contains("Bearer"));
        remove_login_header(url).unwrap();
        assert!(get_login_header(url).is_none());
    }
}
