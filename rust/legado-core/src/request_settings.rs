//! 通用网络任务并发值；不负责存储、运行时或源级限速。
use std::num::NonZeroUsize;
pub const DEFAULT_THREAD_COUNT: usize = 16;
pub const MAX_THREAD_COUNT: usize = 256;

/// 缺失或非法配置回落默认值；各任务的专用上限由消费者另行约束。
pub fn parse_thread_count(value: Option<&str>) -> NonZeroUsize {
    value
        .and_then(|v| v.trim().parse::<usize>().ok())
        .filter(|v| (1..=MAX_THREAD_COUNT).contains(v))
        .and_then(NonZeroUsize::new)
        .unwrap_or(NonZeroUsize::new(DEFAULT_THREAD_COUNT).unwrap())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn range_and_default_are_explicit() {
        for value in [
            None,
            Some(""),
            Some("bad"),
            Some("0x20"),
            Some("0"),
            Some("-1"),
            Some("257"),
        ] {
            assert_eq!(parse_thread_count(value).get(), 16);
        }
        assert_eq!(parse_thread_count(Some(" 1 ")).get(), 1);
        assert_eq!(parse_thread_count(Some("256")).get(), 256);
    }
}
