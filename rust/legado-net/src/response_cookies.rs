//! reqwest 与上层只使用同一 CookieStore；请求级开关覆盖整个重定向链。

use std::sync::{Arc, RwLock};

use crate::{CookiePersistence, CookieStore};

tokio::task_local! {
    // 只表达当前请求的写入许可，不隐式查找引擎或跨请求传递状态。
    static WRITE_RESPONSE_COOKIES: bool;
}

pub(crate) async fn send(
    request: reqwest::RequestBuilder,
    enabled: bool,
) -> Result<reqwest::Response, reqwest::Error> {
    WRITE_RESPONSE_COOKIES
        .scope(enabled, async { request.send().await })
        .await
}

pub(crate) struct SharedCookieJar {
    pub store: Arc<RwLock<CookieStore>>,
    pub persistence: Option<Arc<dyn CookiePersistence>>,
}

impl reqwest::cookie::CookieStore for SharedCookieJar {
    fn set_cookies(
        &self,
        headers: &mut dyn Iterator<Item = &reqwest::header::HeaderValue>,
        url: &url::Url,
    ) {
        if !WRITE_RESPONSE_COOKIES
            .try_with(|enabled| *enabled)
            .unwrap_or(false)
        {
            return;
        }
        save_response_cookies(
            &self.store,
            self.persistence.as_ref(),
            url.as_str(),
            headers.filter_map(|value| value.to_str().ok()),
        );
    }

    fn cookies(&self, url: &url::Url) -> Option<reqwest::header::HeaderValue> {
        let value = self.store.read().ok()?.get_cookie_string(url.as_str());
        if value.is_empty() {
            None
        } else {
            value.parse().ok()
        }
    }
}

/// 按域串行更新和捕获 jar；释放 jar 写锁后才调用持久化后端。
pub(crate) fn save_response_cookies<'a>(
    store: &Arc<RwLock<CookieStore>>,
    persistence: Option<&Arc<dyn CookiePersistence>>,
    url: &str,
    values: impl Iterator<Item = &'a str>,
) {
    let domain = crate::cookie_store::cookie_domain_key(url).unwrap_or_else(|| url.to_owned());
    let values: Vec<_> = values.collect();
    if values.is_empty() {
        return;
    }
    crate::cookie_store::write_coordinator(store).with_domain(&domain, || {
        let cookie_string = {
            let Ok(mut jar) = store.write() else {
                return;
            };
            for value in values {
                if let Some(name_value) = value.split(';').next()
                    && let Some((name, value)) = name_value.trim().split_once('=')
                {
                    jar.set_cookie(crate::cookie_store::Cookie {
                        name: name.trim().to_owned(),
                        value: value.trim().to_owned(),
                        domain: domain.clone(),
                        path: "/".to_owned(),
                        expires: None,
                        secure: false,
                        http_only: false,
                    });
                }
            }
            jar.domain_cookie_string(&domain)
        };
        if !cookie_string.is_empty()
            && let Some(persistence) = persistence
        {
            persistence.save(&domain, &cookie_string);
        }
    })
}
