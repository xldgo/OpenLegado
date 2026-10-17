//! 书源工具固定快照；脚本与平台动作保留文档边界。— Codex + Bridge
use crate::ffi::BridgeError;

#[derive(Debug, Clone)]
pub struct CoverCandidateDto {
    pub url: String,
    pub width: i32,
    pub height: i32,
}
impl From<crate::api::search::CoverCandidate> for CoverCandidateDto {
    fn from(v: crate::api::search::CoverCandidate) -> Self {
        Self {
            url: v.url,
            width: v.width,
            height: v.height,
        }
    }
}
#[derive(Debug, Clone)]
pub struct CoverRuleDto {
    pub enable: bool,
    pub search_url: String,
    pub cover_rule: String,
    pub enabled_cookie_jar: Option<bool>,
}
impl From<crate::api::cover_api::CoverRuleConfig> for CoverRuleDto {
    fn from(v: crate::api::cover_api::CoverRuleConfig) -> Self {
        Self {
            enable: v.enable,
            search_url: v.search_url,
            cover_rule: v.cover_rule,
            enabled_cookie_jar: v.enabled_cookie_jar,
        }
    }
}
impl From<CoverRuleDto> for crate::api::cover_api::CoverRuleConfig {
    fn from(v: CoverRuleDto) -> Self {
        Self {
            enable: v.enable,
            search_url: v.search_url,
            cover_rule: v.cover_rule,
            enabled_cookie_jar: v.enabled_cookie_jar,
        }
    }
}
#[derive(Debug, Clone)]
pub struct SourceSyntaxDto {
    pub valid: bool,
    pub message: String,
    pub line: Option<u32>,
}
impl From<legado_js::js_source::js_source_config::SyntaxCheckResult> for SourceSyntaxDto {
    fn from(v: legado_js::js_source::js_source_config::SyntaxCheckResult) -> Self {
        Self {
            valid: v.valid,
            message: v.message,
            line: v.line,
        }
    }
}
#[derive(Debug, Clone)]
pub enum ChapterPurchaseKindDto {
    Url,
    Success,
    None,
}
#[derive(Debug, Clone)]
pub struct ChapterPurchaseDto {
    pub kind: ChapterPurchaseKindDto,
    pub value: String,
}
impl TryFrom<crate::api::pay_action_api::PayActionResult> for ChapterPurchaseDto {
    type Error = BridgeError;
    fn try_from(v: crate::api::pay_action_api::PayActionResult) -> Result<Self, Self::Error> {
        let kind = match v.kind.as_str() {
            "url" => ChapterPurchaseKindDto::Url,
            "success" => ChapterPurchaseKindDto::Success,
            "none" => ChapterPurchaseKindDto::None,
            _ => {
                return Err(BridgeError {
                    message: "未知购买动作类型".into(),
                });
            }
        };
        Ok(Self {
            kind,
            value: v.value,
        })
    }
}
#[derive(Debug, Clone)]
pub struct SourceCallbackDto {
    pub invoked: bool,
    pub js_true: bool,
    pub raw: String,
    pub actions_json: String,
}
impl TryFrom<crate::api::source_callback_api::SourceCallBackBtnResult> for SourceCallbackDto {
    type Error = BridgeError;
    fn try_from(
        v: crate::api::source_callback_api::SourceCallBackBtnResult,
    ) -> Result<Self, Self::Error> {
        Ok(Self {
            invoked: v.invoked,
            js_true: v.js_true,
            raw: v.raw,
            actions_json: serde_json::to_string(&v.actions)?,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn purchase_kind_is_closed_and_never_defaults_to_success() {
        for (kind, expected) in [
            ("url", ChapterPurchaseKindDto::Url),
            ("success", ChapterPurchaseKindDto::Success),
            ("none", ChapterPurchaseKindDto::None),
        ] {
            let result =
                ChapterPurchaseDto::try_from(crate::api::pay_action_api::PayActionResult {
                    kind: kind.into(),
                    value: "原始返回😀".into(),
                })
                .unwrap();
            assert_eq!(
                std::mem::discriminant(&result.kind),
                std::mem::discriminant(&expected)
            );
            assert_eq!(result.value, "原始返回😀");
        }
        assert!(
            ChapterPurchaseDto::try_from(crate::api::pay_action_api::PayActionResult {
                kind: "unknown".into(),
                value: String::new()
            })
            .is_err()
        );
    }

    #[test]
    fn callback_keeps_dynamic_actions_in_order_with_unknown_fields() {
        let actions = vec![
            serde_json::json!({"action":"copyText", "extra":{"keep":true}}),
            serde_json::json!({"action":"unknown", "payload":[1,null,"😀"]}),
        ];
        let result =
            SourceCallbackDto::try_from(crate::api::source_callback_api::SourceCallBackBtnResult {
                invoked: true,
                js_true: false,
                raw: "false".into(),
                actions: actions.clone(),
            })
            .unwrap();
        assert!(result.invoked);
        assert!(!result.js_true);
        assert_eq!(result.raw, "false");
        assert_eq!(
            serde_json::from_str::<Vec<serde_json::Value>>(&result.actions_json).unwrap(),
            actions
        );
    }
}
