//! HTTP 发送和响应读取共用的诊断格式化，不改变各调用方的错误分类。

/// 保留 reqwest 外层消息并最多展开5层来源。
///
/// DNS、TCP、TLS 失败及正文截断的原因通常位于 source 链中，
/// 单独格式化 reqwest 的 Display 无法区分这些故障。
pub(crate) fn reqwest_error_chain(e: &reqwest::Error) -> String {
    let mut msg = e.to_string();
    let mut src: Option<&dyn std::error::Error> = std::error::Error::source(e);
    let mut depth = 0;
    while let Some(s) = src {
        depth += 1;
        msg.push_str(&format!(" <- {}", s));
        if depth >= 5 {
            break;
        }
        src = s.source();
    }
    msg
}
