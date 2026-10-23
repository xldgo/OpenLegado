//! 备份外层认证加密。密钥派生与AEAD由ring实现，不使用上游的弱密码派生创建新包。
use legado_core::{LegadoError, LegadoResult};
use ring::{
    aead, pbkdf2,
    rand::{SecureRandom, SystemRandom},
};
use std::num::NonZeroU32;

const MAGIC: &[u8] = b"OPENLEGADO-BACKUP\x01";
const SALT_LEN: usize = 32;
const NONCE_LEN: usize = 12;
pub(super) fn is_sealed(bytes: &[u8]) -> bool {
    bytes.starts_with(MAGIC)
}
fn failure() -> LegadoError {
    LegadoError::Parser("本地密码错误或备份已损坏".into())
}
fn key(password: &str, salt: &[u8]) -> LegadoResult<aead::LessSafeKey> {
    let mut bytes = [0; 32];
    pbkdf2::derive(
        pbkdf2::PBKDF2_HMAC_SHA256,
        NonZeroU32::new(600_000).unwrap(),
        salt,
        password.as_bytes(),
        &mut bytes,
    );
    aead::UnboundKey::new(&aead::AES_256_GCM, &bytes)
        .map(aead::LessSafeKey::new)
        .map_err(|_| failure())
}
pub(super) fn seal(mut plaintext: Vec<u8>, password: Option<&str>) -> LegadoResult<Vec<u8>> {
    let Some(password) = password.filter(|value| !value.is_empty()) else {
        return Ok(plaintext);
    };
    let random = SystemRandom::new();
    let mut salt = [0; SALT_LEN];
    let mut nonce = [0; NONCE_LEN];
    random.fill(&mut salt).map_err(|_| failure())?;
    random.fill(&mut nonce).map_err(|_| failure())?;
    key(password, &salt)?
        .seal_in_place_append_tag(
            aead::Nonce::assume_unique_for_key(nonce),
            aead::Aad::from(MAGIC),
            &mut plaintext,
        )
        .map_err(|_| failure())?;
    let mut output = Vec::with_capacity(MAGIC.len() + SALT_LEN + NONCE_LEN + plaintext.len());
    output.extend_from_slice(MAGIC);
    output.extend_from_slice(&salt);
    output.extend_from_slice(&nonce);
    output.extend_from_slice(&plaintext);
    Ok(output)
}
pub(super) fn open(bytes: Vec<u8>, password: Option<&str>) -> LegadoResult<Vec<u8>> {
    if !bytes.starts_with(MAGIC) {
        return Ok(bytes);
    }
    let password = password
        .filter(|value| !value.is_empty())
        .ok_or_else(|| LegadoError::Parser("备份已加密，请先设置相同的本地密码".into()))?;
    let start = MAGIC.len();
    let payload_start = start + SALT_LEN + NONCE_LEN;
    if bytes.len() < payload_start + aead::AES_256_GCM.tag_len() {
        return Err(failure());
    }
    let nonce: [u8; NONCE_LEN] = bytes[start + SALT_LEN..payload_start]
        .try_into()
        .map_err(|_| failure())?;
    let secret = key(password, &bytes[start..start + SALT_LEN])?;
    let mut payload = bytes[payload_start..].to_vec();
    let plaintext = secret
        .open_in_place(
            aead::Nonce::assume_unique_for_key(nonce),
            aead::Aad::from(MAGIC),
            &mut payload,
        )
        .map_err(|_| failure())?;
    Ok(plaintext.to_vec())
}
