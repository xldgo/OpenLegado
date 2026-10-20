//! 参考上游 HttpTtsEmotionMapper，按目录映射情感，不推测服务商私有标签。
use crate::tts_catalog::EmotionDraft;

const ALIASES: &[&[&str]] = &[
    &["neutral", "default", "默认", "中性", "正常"],
    &["cheerful", "happy", "开心", "高兴", "快乐", "愉快"],
    &["sad", "sadness", "悲伤", "伤心", "难过"],
    &["angry", "anger", "愤怒", "生气"],
    &["fearful", "fear", "scared", "害怕", "恐惧"],
    &["surprised", "surprise", "惊讶", "吃惊"],
    &["disgusted", "disgust", "厌恶", "反感"],
    &["whispering", "whisper", "耳语", "小声", "低语"],
    &["calm", "平静", "冷静"],
];

pub fn map_emotion(input: &str, catalog: &[EmotionDraft]) -> EmotionDraft {
    if catalog.is_empty() {
        return EmotionDraft {
            emotion_name: String::new(),
            emotion_tag: input.into(),
        };
    }
    let key = input.trim().to_lowercase();
    if let Some(found) = catalog
        .iter()
        .find(|e| e.emotion_name.to_lowercase() == key || e.emotion_tag.to_lowercase() == key)
    {
        return found.clone();
    }
    let matches = |e: &&EmotionDraft, aliases: &[&str]| {
        aliases.contains(&e.emotion_name.to_lowercase().as_str())
            || aliases.contains(&e.emotion_tag.to_lowercase().as_str())
    };
    if let Some(aliases) = ALIASES
        .iter()
        .find(|aliases| aliases.contains(&key.as_str()))
        && let Some(found) = catalog.iter().find(|e| matches(e, aliases))
    {
        return found.clone();
    }
    catalog
        .iter()
        .find(|e| matches(e, ALIASES[0]))
        .cloned()
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    fn emotion(name: &str, tag: &str) -> EmotionDraft {
        EmotionDraft {
            emotion_name: name.into(),
            emotion_tag: tag.into(),
        }
    }
    #[test]
    fn direct_alias_and_unknown_follow_catalog() {
        let catalog = vec![
            emotion("高兴", "private_happy"),
            emotion("正常", "private_neutral"),
        ];
        for input in ["高兴", "PRIVATE_HAPPY", " HAPPY ", "cheerful"] {
            assert_eq!(map_emotion(input, &catalog), catalog[0]);
        }
        assert_eq!(map_emotion("未知", &catalog), catalog[1]);
        assert_eq!(map_emotion("", &catalog), catalog[1]);
        assert_eq!(map_emotion("未知", &catalog[..1]), EmotionDraft::default());
        assert_eq!(map_emotion("custom", &[]), emotion("", "custom"));
    }
}
