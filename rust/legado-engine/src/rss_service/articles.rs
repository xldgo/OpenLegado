//! 文章抓取、原始缓存及既有摘要回退。
use super::*;
use std::collections::HashMap;
impl RssService {
    pub fn clear_rss_articles(&self, source_url: &str) -> LegadoResult<()> {
        self.with_database(|db| {
            let repo = legado_db::RssArticleRepository::new(db.connection());
            repo.delete_by_source(source_url)
        })
    }

    pub fn fetch_rss_articles(
        &self,
        source_url: &str,
        network: &NetworkContext,
        runtime: &tokio::runtime::Handle,
    ) -> LegadoResult<Vec<RssArticle>> {
        // 批 2 写侧门控：读取 RSS 源的 enabledCookieJar 开关（与 feedUrl 同查，
        // 免二次查询）——开启时 feed 请求携带内部标记头，响应 Set-Cookie 落库；
        // 关闭/NULL → 无标记（不写回，对齐上游 AnalyzeUrl(source=rssSource) 门控）。
        let (feed_url, cache_first, cookie_jar_enabled) = self.with_database(|db| {
            let conn = db.connection();
            let mut stmt = conn
                .prepare(
                    "SELECT sourceUrl, COALESCE(cacheFirst, 0), COALESCE(enabledCookieJar, 0) \
                 FROM rssSources WHERE sourceUrl = ?1",
                )
                .map_err(|e| LegadoError::Database(format!("查询 RSS 源失败: {e}")))?;
            let mut rows = stmt
                .query_map(rusqlite::params![source_url], |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, i32>(1)? != 0,
                        row.get::<_, i32>(2)? != 0,
                    ))
                })
                .map_err(|e| LegadoError::Database(format!("查询失败: {e}")))?;
            match rows.next() {
                Some(Ok(v)) => Ok(v),
                _ => Err(LegadoError::Database("RSS 源不存在".into())),
            }
        })?;

        if cache_first {
            let cached = self.with_database(|db| {
                let repo = legado_db::RssArticleRepository::new(db.connection());
                repo.find_by_source(source_url, 500)
            })?;
            if !cached.is_empty() {
                return Ok(cached
                    .into_iter()
                    .map(|a| RssArticle {
                        title: a.title,
                        link: a.link.unwrap_or_default(),
                        description: a.description,
                        pub_date: a.pub_date,
                        image_url: a.image,
                    })
                    .collect());
            }
        }

        let articles = runtime.block_on(async {
            let client = network.client()?;
            // 写侧门控（批 2）：开启源补内部标记头（只补不覆盖；发送前由
            // legado-net 剥离、绝不出网）；读侧 cookie 注入不受影响。
            let headers_opt = if cookie_jar_enabled {
                let mut headers = HashMap::new();
                headers.insert(legado_net::COOKIE_JAR_HEADER.to_string(), "1".to_string());
                Some(headers)
            } else {
                None
            };
            // data URI 短路豁免登记（审查 2026-10-06 建议项 3，不改行为）：
            // feed_url 来自 rssSources.sourceUrl —— RSS 源的唯一标识/用户显式配置
            // 项，上游 RSS 源均为 http(s)，不经书源 jsLib/规则生成，故不属于
            // 「书源规则面」；data: 形态不构成现实缺陷面，此处不做统一短路。
            // 书源规则面直连路径（fetch_page / fetch_simple_cached / search
            // send_raw / dict send_text / explore）均已在 fd04ee1154 批次接入
            // `data_uri_content_of` 同款短路。若未来 RSS 源支持 jsLib 或规则
            // 生成 feedUrl，再评估接入，勿重复排查此点。
            let response = client.get(&feed_url, headers_opt).await?;
            if !response.is_success() {
                return Err(LegadoError::Network(format!(
                    "获取 RSS 内容失败: HTTP {}",
                    response.status
                )));
            }
            match legado_net::rss::parse_feed(&response.body) {
                Ok(feed) if !feed.articles.is_empty() => Ok(feed
                    .articles
                    .into_iter()
                    .map(|a| RssArticle {
                        title: a.title,
                        link: a.link,
                        description: a.description,
                        pub_date: a.pub_date,
                        image_url: a.image_url,
                    })
                    .collect::<Vec<_>>()),
                _ => {
                    // 非标准 XML / 规则源：保留单条摘要回退，避免整页空白
                    Ok(vec![RssArticle {
                        title: feed_url.clone(),
                        link: feed_url.clone(),
                        description: Some(response.body.chars().take(200).collect()),
                        pub_date: None,
                        image_url: None,
                    }])
                }
            }
        })?;

        // 写入本地文章缓存（对齐原版 rssArticles）
        let _ = self.with_database(|db| {
            let repo = legado_db::RssArticleRepository::new(db.connection());
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_millis() as i64)
                .unwrap_or(0);
            for (i, a) in articles.iter().enumerate() {
                let record = legado_db::RssArticleRecord {
                    origin: source_url.to_string(),
                    sort: String::new(),
                    title: a.title.clone(),
                    order: now - i as i64,
                    link: Some(a.link.clone()),
                    pub_date: a.pub_date.clone(),
                    description: a.description.clone(),
                    content: None,
                    image: a.image_url.clone(),
                    variable: None,
                    ..Default::default()
                };
                let _ = repo.insert(&record);
            }
            Ok(())
        });

        Ok(articles)
    }
}
