//! 驱动错误在数据层分类，原始原因保留到最终显示边界。
use legado_core::{LegadoError, error::DatabaseErrorKind};
pub fn database_error(
    context: impl Into<String>,
    source: impl std::error::Error + Send + Sync + 'static,
) -> LegadoError {
    let kind = match (&source as &dyn std::error::Error).downcast_ref::<rusqlite::Error>() {
        Some(rusqlite::Error::SqliteFailure(code, _)) => match code.code {
            rusqlite::ErrorCode::DatabaseBusy => DatabaseErrorKind::Busy,
            rusqlite::ErrorCode::DatabaseLocked => DatabaseErrorKind::Locked,
            rusqlite::ErrorCode::ConstraintViolation => DatabaseErrorKind::Constraint,
            _ => DatabaseErrorKind::Other,
        },
        Some(
            rusqlite::Error::InvalidColumnType(..)
            | rusqlite::Error::FromSqlConversionFailure(..)
            | rusqlite::Error::IntegralValueOutOfRange(..),
        ) => DatabaseErrorKind::Conversion,
        _ => DatabaseErrorKind::Other,
    };
    LegadoError::DatabaseFailure {
        kind,
        context: context.into(),
        source: Box::new(source),
    }
}
