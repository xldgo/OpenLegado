//! 朗读纯计算的类型化范围快照，不返回重复正文。— Codex + Bridge
use legado_core::read_aloud_partition::{ReadAloudUnit, SplitMode};
use legado_layout::model::SourceRange;

pub enum ReadAloudSplitModeDto {
    Paragraph,
    Symbols,
    Page,
}
impl From<ReadAloudSplitModeDto> for SplitMode {
    fn from(value: ReadAloudSplitModeDto) -> Self {
        match value {
            ReadAloudSplitModeDto::Paragraph => Self::Paragraph,
            ReadAloudSplitModeDto::Symbols => Self::Symbols,
            ReadAloudSplitModeDto::Page => Self::Page,
        }
    }
}
pub struct ReadAloudRangeDto {
    pub start: usize,
    pub end: usize,
}
impl From<ReadAloudRangeDto> for SourceRange {
    fn from(value: ReadAloudRangeDto) -> Self {
        Self {
            start_offset: value.start,
            end_offset: value.end,
        }
    }
}
impl From<SourceRange> for ReadAloudRangeDto {
    fn from(value: SourceRange) -> Self {
        Self {
            start: value.start_offset,
            end: value.end_offset,
        }
    }
}
pub struct ReadAloudUnitDto {
    pub start: usize,
    pub end: usize,
    pub source_paragraph_index: usize,
    pub is_paragraph_end: bool,
}
impl From<ReadAloudUnit> for ReadAloudUnitDto {
    fn from(value: ReadAloudUnit) -> Self {
        Self {
            start: value.range.start_offset,
            end: value.range.end_offset,
            source_paragraph_index: value.source_paragraph_index,
            is_paragraph_end: value.is_paragraph_end,
        }
    }
}
pub struct SpeechPartitionDto {
    pub ranges: Vec<ReadAloudRangeDto>,
}
