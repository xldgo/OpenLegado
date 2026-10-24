//! MD3高亮样式；存于既有style JSON，测量和绘制消费同一份规范化结果。
use crate::{LegadoError, LegadoResult};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default, rename_all = "camelCase")]
pub struct HighlightStyle {
    pub sample_text: String,
    pub target_scope: i32,
    pub text_color: Option<i64>,
    pub bg_color: Option<i64>,
    pub underline_mode: i32,
    pub underline_color: Option<i64>,
    pub underline_width: f32,
    pub underline_offset: f32,
    pub underline_svg_path: Option<String>,
    pub bg_image: Option<String>,
    pub bg_image_fit: i32,
    pub bg_image_scale: f32,
    pub config_name: Option<String>,
    pub font_path: Option<String>,
    pub font_weight: i32,
    pub is_italic: bool,
    pub font_size_offset: i32,
    pub np_left: f32,
    pub np_right: f32,
    pub np_top: f32,
    pub np_bottom: f32,
    pub manual_nine_slice: bool,
    pub letter_spacing_before: f32,
    pub letter_spacing_after: f32,
    pub line_spacing_top: f32,
    pub line_spacing_bottom: f32,
    pub bg_length_offset_left: f32,
    pub bg_length_offset_right: f32,
}
impl Default for HighlightStyle {
    fn default() -> Self {
        Self {
            sample_text: String::new(),
            target_scope: 0,
            text_color: None,
            bg_color: None,
            underline_mode: 0,
            underline_color: None,
            underline_width: 1.0,
            underline_offset: 2.0,
            underline_svg_path: None,
            bg_image: None,
            bg_image_fit: 0,
            bg_image_scale: 1.0,
            config_name: None,
            font_path: None,
            font_weight: 400,
            is_italic: false,
            font_size_offset: 0,
            np_left: 0.1,
            np_right: 0.1,
            np_top: 0.1,
            np_bottom: 0.1,
            manual_nine_slice: true,
            letter_spacing_before: 0.0,
            letter_spacing_after: 0.0,
            line_spacing_top: 0.0,
            line_spacing_bottom: 0.0,
            bg_length_offset_left: 0.0,
            bg_length_offset_right: 0.0,
        }
    }
}
impl HighlightStyle {
    pub fn parse(json: &str) -> LegadoResult<Self> {
        let style = if json.trim().is_empty() {
            Self::default()
        } else {
            serde_json::from_str(json)
                .map_err(|e| LegadoError::Parser(format!("高亮样式无效：{e}")))?
        };
        style.normalized()
    }
    pub fn normalized(mut self) -> LegadoResult<Self> {
        for color in [self.text_color, self.bg_color, self.underline_color]
            .into_iter()
            .flatten()
        {
            if !(-2147483648..=4294967295).contains(&color) {
                return Err(LegadoError::Parser("高亮颜色必须是32位ARGB值".into()));
            }
        }
        if !(0..=2).contains(&self.target_scope) {
            self.target_scope = 0;
        }
        if let Some(binding) = self.config_name.as_mut().filter(|v| !v.trim().is_empty()) {
            if !binding.trim_start().starts_with('[') {
                *binding = serde_json::to_string(&vec![binding.clone()])?;
            } else {
                serde_json::from_str::<Vec<String>>(binding).map_err(|e| {
                    LegadoError::Parser(format!("阅读配置绑定必须是名称或字符串数组：{e}"))
                })?;
            }
        }
        self.underline_mode = self.underline_mode.clamp(0, 7);
        self.underline_width = self.underline_width.clamp(0.1, 10.0);
        self.underline_offset = self.underline_offset.clamp(0.0, 20.0);
        self.bg_image_fit = self.bg_image_fit.clamp(0, 3);
        self.bg_image_scale = self.bg_image_scale.clamp(0.1, 5.0);
        self.font_weight = self.font_weight.clamp(300, 700);
        self.font_size_offset = self.font_size_offset.clamp(-10, 10);
        for value in [
            &mut self.np_left,
            &mut self.np_right,
            &mut self.np_top,
            &mut self.np_bottom,
        ] {
            *value = value.clamp(0.0, 1.0);
        }
        for value in [
            &mut self.letter_spacing_before,
            &mut self.letter_spacing_after,
            &mut self.line_spacing_top,
            &mut self.line_spacing_bottom,
        ] {
            *value = value.clamp(0.0, 40.0);
        }
        self.bg_length_offset_left = self.bg_length_offset_left.clamp(-40.0, 40.0);
        self.bg_length_offset_right = self.bg_length_offset_right.clamp(-40.0, 40.0);
        Ok(self)
    }
    pub fn json(&self) -> LegadoResult<String> {
        serde_json::to_string(self).map_err(|e| LegadoError::Parser(e.to_string()))
    }
}
