//! SSE原始事件分帧；业务JSON、错误与合成完成条件仍由Provider解释。— Codex + Rust
//! 只处理已经取得的完整响应，不负责HTTP连接、重试或浏览器EventSource状态。

pub(crate) struct Frame<'a> {
    pub event: &'a str,
    /// 保留无data的命名帧，让Provider仍可拒绝仅带事件名的错误通知。
    pub data: Option<String>,
}

pub(crate) fn frames(input: &str) -> Frames<'_> {
    Frames {
        remaining: input.strip_prefix('\u{feff}').unwrap_or(input),
    }
}

pub(crate) struct Frames<'a> {
    remaining: &'a str,
}

impl<'a> Frames<'a> {
    fn line(&mut self) -> Option<&'a str> {
        let Some(end) = self.remaining.find(['\r', '\n']) else {
            self.remaining = "";
            return None;
        };
        let (line, tail) = self.remaining.split_at(end);
        self.remaining = tail.strip_prefix("\r\n").unwrap_or(&tail[1..]);
        Some(line)
    }
}

impl<'a> Iterator for Frames<'a> {
    type Item = Frame<'a>;

    fn next(&mut self) -> Option<Self::Item> {
        let mut event = "";
        let mut data: Option<String> = None;
        while let Some(line) = self.line() {
            if line.is_empty() {
                if event.is_empty() && data.is_none() {
                    continue;
                }
                if let Some(data) = &mut data {
                    data.pop(); // 每个data字段都追加一个换行，提交时只移除最后一个。
                }
                return Some(Frame {
                    event: if event.is_empty() { "message" } else { event },
                    data,
                });
            }
            let (field, value) = line.split_once(':').unwrap_or((line, ""));
            let value = value.strip_prefix(' ').unwrap_or(value);
            match field {
                "event" => event = value,
                "data" => {
                    let data = data.get_or_insert_with(String::new);
                    data.push_str(value);
                    data.push('\n');
                }
                // 注释、id/retry和未知字段不参与本应用的音频事件解码。
                _ => {}
            }
        }
        // 未由空行终止的尾帧不提交，避免截断响应冒充合成完成。
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn line_endings_bom_comments_and_multiline_data_share_one_frame_contract() {
        for ending in ["\n", "\r\n", "\r"] {
            let stream = format!(
                "\u{feff}{}",
                [
                    ": 心跳",
                    "id: 1",
                    "retry: 1000",
                    "unknown: 忽略",
                    "event: replaced",
                    "event: audio",
                    "data:  第一行😀",
                    "data: second:part",
                    "",
                    "data",
                    "",
                    "",
                ]
                .join(ending)
            );
            let events: Vec<_> = frames(&stream).collect();
            assert_eq!(events.len(), 2);
            assert_eq!(events[0].event, "audio");
            assert_eq!(events[0].data.as_deref(), Some(" 第一行😀\nsecond:part"));
            assert_eq!(events[1].event, "message");
            assert_eq!(events[1].data.as_deref(), Some(""));
        }
    }

    #[test]
    fn unfinished_tail_is_not_committed_after_a_complete_event() {
        for tail in [
            "data: cut",
            "data: cut\n",
            "event: finished\ndata: done\r\n",
        ] {
            let stream = format!("data: first\n\n{tail}");
            let events: Vec<_> = frames(&stream).collect();
            assert_eq!(events.len(), 1);
            assert_eq!(events[0].data.as_deref(), Some("first"));
        }
    }

    #[test]
    fn named_error_without_data_is_preserved_for_the_provider() {
        let events: Vec<_> = frames(": 心跳\n\nevent: error\n\n").collect();
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].event, "error");
        assert!(events[0].data.is_none());
    }
}
