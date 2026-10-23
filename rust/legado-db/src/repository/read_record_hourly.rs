//! 小时槽由平台日历提供，Rust仅查询相交会话并汇总时长。— Codex + Rust
use legado_core::LegadoResult;
use rusqlite::Connection;

pub fn query_read_hourly(conn: &Connection, boundaries: &[i64]) -> LegadoResult<Vec<i64>> {
    // 边界由唯一Flutter入口固定生成，运行时检查按用户要求注释保留。
    // if boundaries.len() != 25
    //     || boundaries.windows(2).any(|b| b[0] > b[1])
    //     || boundaries[0] >= boundaries[24]
    // {
    //     return Err(legado_core::LegadoError::Internal(
    //         "小时统计需要25个非递减边界，且首尾时间不同".into(),
    //     ));
    // }
    let mut statement = conn
        .prepare(
            "SELECT startTime,endTime FROM readRecordSession
             WHERE startTime < ?2 AND endTime > ?1 AND endTime > startTime",
        )
        .map_err(|e| crate::error::database_error("准备小时会话查询失败", e))?;
    let sessions = statement
        .query_map([boundaries[0], boundaries[24]], |row| {
            Ok((row.get::<_, i64>(0)?, row.get::<_, i64>(1)?))
        })
        .map_err(|e| crate::error::database_error("查询小时会话失败", e))?;
    let mut milliseconds = vec![0_i64; 24];
    for session in sessions {
        let (start, end) =
            session.map_err(|e| crate::error::database_error("读取小时会话失败", e))?;
        for (index, slot) in boundaries.windows(2).enumerate() {
            milliseconds[index] += (end.min(slot[1]) - start.max(slot[0])).max(0);
        }
    }
    Ok(milliseconds.into_iter().map(|ms| ms / 1000).collect())
}

#[cfg(test)]
mod tests;
