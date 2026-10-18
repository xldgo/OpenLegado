//! 请求级DNS覆盖；不改写宿主hosts或URL，覆盖同一客户端的重定向查找。
use std::net::{IpAddr, SocketAddr};
use std::time::Duration;

use reqwest::dns::{Addrs, Name, Resolve, Resolving};

/// 对齐参考版parseIpsFromString：逗号分隔、忽略失败项，每个主机取首个地址。
/// 调用方在可取消的请求future中等待；空结果表示沿用原解析器。
pub async fn resolve_addresses(input: Option<&str>) -> Vec<IpAddr> {
    let mut addresses = Vec::new();
    for item in input
        .unwrap_or_default()
        .split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        let literal = item
            .strip_prefix('[')
            .and_then(|s| s.strip_suffix(']'))
            .unwrap_or(item);
        if let Ok(ip) = literal.parse::<IpAddr>() {
            addresses.push(ip);
        } else if let Ok(mut resolved) = tokio::net::lookup_host((item, 0)).await
            && let Some(address) = resolved.next()
        {
            addresses.push(address.ip());
        }
    }
    addresses
}

pub(crate) struct RequestDnsResolver(pub Vec<IpAddr>);
impl Resolve for RequestDnsResolver {
    fn resolve(&self, name: Name) -> Resolving {
        let addresses: Vec<_> = self.0.iter().map(|ip| SocketAddr::new(*ip, 0)).collect();
        crate::timing::record_dns(name.as_str(), Duration::ZERO, addresses.clone());
        let addresses: Addrs = Box::new(addresses.into_iter());
        Box::pin(async move { Ok(addresses) })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn addresses_accept_literals_hosts_and_skip_failed_entries() {
        assert_eq!(
            resolve_addresses(Some(" ,127.0.0.1,::zz,[::1],127.0.0.1")).await,
            vec![
                "127.0.0.1".parse::<IpAddr>().unwrap(),
                "::1".parse().unwrap(),
                "127.0.0.1".parse().unwrap()
            ]
        );
        assert!(resolve_addresses(None).await.is_empty());
        assert!(resolve_addresses(Some(" ,::zz,")).await.is_empty());
        let host = resolve_addresses(Some("localhost")).await;
        assert_eq!(host.len(), 1);
        assert!(host[0].is_loopback());
    }
}
