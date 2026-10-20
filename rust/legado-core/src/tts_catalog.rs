//! 上游 HttpTtsCatalogParser 的纯数据解析；目录不写回 HttpTTS 实体。
use serde::{Deserialize, Serialize};
use serde_json::Value;
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct SpeakerDraft {
    pub speaker_name: String,
    #[serde(rename = "toneID")]
    pub tone_id: String,
    pub tags: Vec<String>,
}
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct EmotionDraft {
    pub emotion_name: String,
    pub emotion_tag: String,
}
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CatalogDraft {
    pub speakers: Vec<SpeakerDraft>,
    pub emotions: Vec<EmotionDraft>,
}
fn primitive(v: &Value) -> Option<String> {
    match v {
        Value::String(s) => Some(s.clone()),
        Value::Number(n) => Some(n.to_string()),
        Value::Bool(b) => Some(b.to_string()),
        _ => None,
    }
}
fn field(v: &Value, keys: &[&str]) -> Option<String> {
    keys.iter()
        .filter_map(|k| v.get(*k).and_then(primitive))
        .find(|s| !s.trim().is_empty())
}
fn elements(root: &Value, key: &str) -> Vec<Value> {
    let Some(text) = root.get(key).and_then(primitive) else {
        return vec![];
    };
    let Ok(value) = serde_json::from_str::<Value>(&text) else {
        return vec![];
    };
    match value {
        Value::Array(a) => a,
        Value::Object(_) => vec![value],
        _ => vec![],
    }
}
fn flatten(root: &Value, key: &str) -> Vec<Value> {
    let mut flat = vec![];
    let mut groups = vec![];
    for item in elements(root, key) {
        if !item.is_object() {
            continue;
        }
        if let Some(items) = item.get("items").and_then(Value::as_array) {
            groups.extend(items.iter().filter(|i| i.is_object()).cloned());
        } else {
            flat.push(item);
        }
    }
    flat.extend(groups);
    flat
}
pub fn parse(root: &Value) -> CatalogDraft {
    let mut speakers = vec![];
    let mut emotions = vec![];
    for item in flatten(root, "speakersJson") {
        if let (Some(name), Some(id)) = (
            field(&item, &["speakerName", "name"]),
            field(&item, &["toneID", "toneId", "tone_id"]),
        ) && !speakers.iter().any(|s: &SpeakerDraft| s.tone_id == id)
        {
            speakers.push(SpeakerDraft {
                speaker_name: name,
                tone_id: id,
                tags: item
                    .get("tags")
                    .and_then(Value::as_array)
                    .into_iter()
                    .flatten()
                    .filter_map(primitive)
                    .filter(|s| !s.trim().is_empty())
                    .collect(),
            });
        }
    }
    for item in flatten(root, "emotionsJson") {
        if let (Some(name), Some(tag)) = (
            field(&item, &["emotionName", "name"]),
            field(&item, &["emotionTag", "tag", "value"]),
        ) && !emotions.iter().any(|e: &EmotionDraft| e.emotion_tag == tag)
        {
            emotions.push(EmotionDraft {
                emotion_name: name,
                emotion_tag: tag,
            });
        }
    }
    CatalogDraft { speakers, emotions }
}
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn flat_before_groups_aliases_first_wins() {
        let draft = parse(
            &json!({"speakersJson":r#"[{"items":[{"name":"组","tone_id":"a"},{"speakerName":"乙","toneId":"b"}]},{"speakerName":"平铺","toneID":"a","tags":["女",1,false,{},""]}]"#,"emotionsJson":r#"[{"items":[{"name":"组情感","tag":"happy"}]},{"emotionName":"高兴","value":"happy"}]"#}),
        );
        assert_eq!(draft.speakers.len(), 2);
        assert_eq!(draft.speakers[0].speaker_name, "平铺");
        assert_eq!(draft.speakers[0].tags, vec!["女", "1", "false"]);
        assert_eq!(draft.emotions[0].emotion_name, "高兴");
    }
    #[test]
    fn malformed_or_missing_ids_do_not_create_catalog() {
        for value in [
            json!({}),
            json!({"speakersJson":[]}),
            json!({"speakersJson":"broken"}),
            json!({"speakersJson":"[{\"name\":\"只有名称\"}]"}),
        ] {
            assert!(parse(&value).speakers.is_empty());
        }
    }
}
