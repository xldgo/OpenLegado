//! Java数字日期格式；不把Java格式字母机械替换为Chrono格式符。
use chrono::{DateTime, Datelike, Timelike, Utc};
use std::fmt::Write;
fn number(output: &mut String, value: u32, width: usize) {
    // String的数字写入不会产生格式错误，宽度来自已有格式串长度。
    write!(output, "{value:0width$}").expect("写入String不能失败");
}
fn zone(output: &mut String, offset_ms: i32, letter: char, width: usize) -> Result<(), String> {
    if letter == 'X' && width > 3 {
        return Err("Java时区X只允许1至3位".into());
    }
    if letter == 'X' && offset_ms == 0 {
        output.push('Z');
        return Ok(());
    }
    // Java先截取整分钟再判断符号，非整分钟仍参与墙上时间的毫秒运算。
    let minutes = i64::from(offset_ms) / 60_000;
    output.push(if minutes < 0 { '-' } else { '+' });
    let absolute = minutes.unsigned_abs();
    number(output, (absolute / 60) as u32, 2);
    if letter == 'Z' || width >= 2 {
        if letter == 'X' && width == 3 {
            output.push(':');
        }
        number(output, (absolute % 60) as u32, 2);
    }
    Ok(())
}
/// date已按毫秒偏移平移；offset_ms仅用于时区字段的输出。
pub(super) fn format(date: DateTime<Utc>, pattern: &str, offset_ms: i32) -> Result<String, String> {
    let mut output = String::with_capacity(pattern.len());
    let mut chars = pattern.chars().peekable();
    let mut quoted = false;
    while let Some(ch) = chars.next() {
        if ch == '\'' {
            if chars.peek() == Some(&'\'') {
                chars.next();
                output.push('\'');
            } else {
                quoted = !quoted;
            }
            continue;
        }
        if quoted || !ch.is_ascii_alphabetic() {
            output.push(ch);
            continue;
        }
        let mut width = 1;
        while chars.peek() == Some(&ch) {
            chars.next();
            width += 1;
        }
        let value = match ch {
            'y' => {
                let year = date.year_ce().1;
                if width == 2 { year % 100 } else { year }
            }
            'M' | 'L' if width <= 2 => date.month(),
            'd' => date.day(),
            'D' => date.ordinal(),
            'F' => (date.day() - 1) / 7 + 1,
            'u' => date.weekday().number_from_monday(),
            'H' => date.hour(),
            'k' => {
                if date.hour() == 0 {
                    24
                } else {
                    date.hour()
                }
            }
            'K' => date.hour() % 12,
            'h' => {
                let hour = date.hour() % 12;
                if hour == 0 { 12 } else { hour }
            }
            'm' => date.minute(),
            's' => date.second(),
            'S' => date.timestamp_subsec_millis(),
            'Z' | 'X' => {
                zone(&mut output, offset_ms, ch, width)?;
                continue;
            }
            'M' | 'L' | 'E' | 'a' | 'G' | 'z' | 'Y' | 'w' | 'W' => {
                return Err(format!("时间格式{ch}需要尚未接入的Locale或周历规则"));
            }
            _ => return Err(format!("无效的Java时间格式字母: {ch}")),
        };
        number(&mut output, value, width);
    }
    if quoted {
        return Err("Java时间格式单引号未闭合".into());
    }
    Ok(output)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn java_year_widths_day_fields_and_literal_percent_match_fixed_vectors() {
        let date = DateTime::from_timestamp_millis(1709251200001).unwrap();
        assert_eq!(
            format(date, "y yy yyyyy M MM D DDD F u S SS SSSS %", 0).unwrap(),
            "2024 24 02024 3 03 61 061 1 5 1 01 0001 %"
        );
        assert_eq!(
            format(date, "'中文'yyyy年M月d日", 0).unwrap(),
            "中文2024年3月1日"
        );
    }
}
