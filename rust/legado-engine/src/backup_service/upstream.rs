//! 原版/参考版ZIP显式适配，不将Android偏好或未知文件直接写入本项目。
use super::package::Decoded;
use legado_core::LegadoResult;
use std::collections::BTreeMap;
pub(super) fn decode(
    files: BTreeMap<String, Vec<u8>>,
    _password: Option<&str>,
) -> LegadoResult<Decoded> {
    let (data, warnings) = legado_db::backup::from_upstream(&files)?;
    Ok(Decoded {
        data,
        preferences: Default::default(),
        sensitive: Default::default(),
        files: BTreeMap::new(),
        resources: BTreeMap::new(),
        warnings,
    })
}
