//! RSA 非对称加密 / 签名 JS 桥接
//!
//! 对应 Kotlin `JsEncodeUtils.kt` 的 `createAsymmetricCrypto(transformation)` 与
//! `createSign(algorithm)`，即 `io.legado.app.help.crypto.AsymmetricCrypto`
//! 与 `Sign`；算法复用RustCrypto，不依赖JVM。
//!
//! JS 用法（对齐 Android 原版）：
//! ```js
//! const rsa = java.createAsymmetricCrypto("RSA/ECB/PKCS1Padding");
//! rsa.setPublicKey(pubKeyB64);
//! const cipher = rsa.encryptBase64("hello");   // 默认公钥加密
//! const plain  = rsa.decryptStr(cipher, false); // false = 使用私钥解密
//!
//! const sign = java.createSign("SHA256withRSA");
//! sign.setPrivateKey(privKeyB64).setPublicKey(pubKeyB64);
//! const sigHex = sign.signHex("data");
//! sign.verify("data", sigHex);                 // -> true
//! ```
//!
//! 密钥支持原始DER及既有PEM/Base64扩展；不将上游String转DER规则误当Base64。

use crate::quickjs_bytes::{ByteArray, TextArg};
use rquickjs::FromJs;

use std::cell::RefCell;
use std::rc::Rc;

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as B64;
use rsa::Pkcs1v15Sign;
use rsa::traits::PublicKeyParts;
use rsa::{Oaep, Pkcs1v15Encrypt, RsaPrivateKey, RsaPublicKey};

// ---------------------------------------------------------------------------
// 填充模式解析（对齐 Java transformation）
// ---------------------------------------------------------------------------

/// RSA 填充模式
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RsaPadding {
    /// RSA/ECB/PKCS1Padding（Java 默认，块大小 k-11）
    Pkcs1v15,
    /// RSA/ECB/OAEPWithSHA-1AndMGF1Padding（块大小 k-42）
    OaepSha1,
    /// RSA/ECB/OAEPWithSHA-256AndMGF1Padding（块大小 k-66）
    OaepSha256,
}

/// 仅接受已经实现的RSA名称与模式，不按子串猜测未知OAEP算法。
pub fn parse_rsa_transformation(transformation: &str) -> Result<RsaPadding, String> {
    let parts: Vec<_> = transformation.split('/').map(str::trim).collect();
    if !parts[0].eq_ignore_ascii_case("RSA") {
        return Err(format!("Unsupported asymmetric algorithm: {}", parts[0]));
    }
    if parts.len() == 1 {
        return Ok(RsaPadding::Pkcs1v15);
    }
    if parts.len() != 3 || !matches!(parts[1].to_ascii_uppercase().as_str(), "ECB" | "NONE") {
        return Err(format!("Invalid RSA transformation: {transformation}"));
    }
    match parts[2].to_ascii_uppercase().as_str() {
        "PKCS1PADDING" => Ok(RsaPadding::Pkcs1v15),
        "OAEPPADDING" | "OAEPWITHSHA-1ANDMGF1PADDING" | "OAEPWITHSHA1ANDMGF1PADDING" => {
            Ok(RsaPadding::OaepSha1)
        }
        "OAEPWITHSHA-256ANDMGF1PADDING" | "OAEPWITHSHA256ANDMGF1PADDING" => {
            Ok(RsaPadding::OaepSha256)
        }
        _ => Err(format!("Unsupported RSA padding: {}", parts[2])),
    }
}

// ---------------------------------------------------------------------------
// 密钥解析（PEM / Base64 DER）
// ---------------------------------------------------------------------------

/// 宽松的 Base64 解码：去除空白并自动补齐填充
fn b64_decode_lenient(s: &str) -> Result<Vec<u8>, String> {
    let cleaned: String = s.chars().filter(|c| !c.is_whitespace()).collect();
    if cleaned.is_empty() {
        return Err("Empty key data".to_string());
    }
    let pad = (4 - cleaned.len() % 4) % 4;
    let padded = format!("{}{}", cleaned, "=".repeat(pad));
    B64.decode(&padded)
        .map_err(|e| format!("Invalid Base64 key data: {}", e))
}

/// 解析 RSA 公钥：支持 PEM（X.509 SPKI / PKCS#1）与 Base64 DER
pub fn parse_public_key(key: &str) -> Result<RsaPublicKey, String> {
    use rsa::pkcs1::DecodeRsaPublicKey;
    use rsa::pkcs8::DecodePublicKey;

    let trimmed = key.trim();
    if trimmed.contains("-----BEGIN") {
        if trimmed.contains("BEGIN PUBLIC KEY") {
            return RsaPublicKey::from_public_key_pem(trimmed)
                .map_err(|e| format!("Failed to parse PEM public key: {}", e));
        }
        if trimmed.contains("BEGIN RSA PUBLIC KEY") {
            return RsaPublicKey::from_pkcs1_pem(trimmed)
                .map_err(|e| format!("Failed to parse PKCS#1 PEM public key: {}", e));
        }
        return Err("Unrecognized PEM public key format".to_string());
    }
    let der = b64_decode_lenient(trimmed)?;
    if let Ok(pk) = RsaPublicKey::from_public_key_der(&der) {
        return Ok(pk);
    }
    RsaPublicKey::from_pkcs1_der(&der).map_err(|e| {
        format!(
            "Cannot parse public key (X.509/PKCS#1 DER or PEM required): {}",
            e
        )
    })
}

/// 解析 RSA 私钥：支持 PEM（PKCS#8 / PKCS#1）与 Base64 DER
pub fn parse_private_key(key: &str) -> Result<RsaPrivateKey, String> {
    use rsa::pkcs1::DecodeRsaPrivateKey;
    use rsa::pkcs8::DecodePrivateKey;

    let trimmed = key.trim();
    if trimmed.contains("-----BEGIN") {
        if trimmed.contains("BEGIN RSA PRIVATE KEY") {
            return RsaPrivateKey::from_pkcs1_pem(trimmed)
                .map_err(|e| format!("Failed to parse PKCS#1 PEM private key: {}", e));
        }
        if trimmed.contains("BEGIN ENCRYPTED PRIVATE KEY") {
            return Err("Encrypted private key is not supported".to_string());
        }
        if trimmed.contains("BEGIN PRIVATE KEY") {
            return RsaPrivateKey::from_pkcs8_pem(trimmed)
                .map_err(|e| format!("Failed to parse PKCS#8 PEM private key: {}", e));
        }
        return Err("Unrecognized PEM private key format".to_string());
    }
    let der = b64_decode_lenient(trimmed)?;
    if let Ok(k) = RsaPrivateKey::from_pkcs8_der(&der) {
        return Ok(k);
    }
    RsaPrivateKey::from_pkcs1_der(&der).map_err(|e| {
        format!(
            "Cannot parse private key (PKCS#8/PKCS#1 DER or PEM required): {}",
            e
        )
    })
}

// ---------------------------------------------------------------------------
// 分段加解密（对齐 hutool 的分块行为）
// ---------------------------------------------------------------------------

/// 公钥分段加密（长数据自动分块，对齐 hutool AsymmetricCrypto.encrypt）
pub fn rsa_encrypt_segmented(
    pub_key: &RsaPublicKey,
    padding: RsaPadding,
    data: &[u8],
) -> Result<Vec<u8>, String> {
    let k = pub_key.size();
    let max_block = max_encrypt_block(k, padding)?;
    let mut rng = rand_core::OsRng;
    let mut out = Vec::with_capacity((data.len() / max_block + 1) * k);
    for chunk in data
        .chunks(max_block)
        .chain(data.is_empty().then_some(&[][..]))
    {
        let enc = match padding {
            RsaPadding::Pkcs1v15 => pub_key.encrypt(&mut rng, Pkcs1v15Encrypt, chunk),
            RsaPadding::OaepSha1 => pub_key.encrypt(&mut rng, Oaep::new::<sha1::Sha1>(), chunk),
            RsaPadding::OaepSha256 => pub_key.encrypt(&mut rng, Oaep::new::<sha2::Sha256>(), chunk),
        }
        .map_err(|e| format!("RSA encrypt failed: {}", e))?;
        out.extend_from_slice(&enc);
    }
    Ok(out)
}

/// 私钥分段解密（密文按模长分块，对齐 hutool AsymmetricCrypto.decrypt）
pub fn rsa_decrypt_segmented(
    priv_key: &RsaPrivateKey,
    padding: RsaPadding,
    data: &[u8],
) -> Result<Vec<u8>, String> {
    let k = priv_key.size();
    if k == 0 || data.is_empty() || !data.len().is_multiple_of(k) {
        return Err(format!(
            "Ciphertext length {} is not a multiple of RSA key size {}",
            data.len(),
            k
        ));
    }
    let mut out = Vec::new();
    for block in data.chunks(k) {
        let dec = match padding {
            RsaPadding::Pkcs1v15 => {
                priv_key.decrypt_blinded(&mut rand_core::OsRng, Pkcs1v15Encrypt, block)
            }
            RsaPadding::OaepSha1 => {
                priv_key.decrypt_blinded(&mut rand_core::OsRng, Oaep::new::<sha1::Sha1>(), block)
            }
            RsaPadding::OaepSha256 => {
                priv_key.decrypt_blinded(&mut rand_core::OsRng, Oaep::new::<sha2::Sha256>(), block)
            }
        }
        .map_err(|e| format!("RSA decrypt failed: {}", e))?;
        out.extend_from_slice(&dec);
    }
    Ok(out)
}

/// 私钥分段加密（PKCS#1 v1.5 type 1，对齐 Java Cipher 私钥加密行为）。
///
/// OAEP 填充不支持私钥加密（与 Java 一致，直接报错）。
pub fn rsa_private_encrypt_segmented(
    priv_key: &RsaPrivateKey,
    padding: RsaPadding,
    data: &[u8],
) -> Result<Vec<u8>, String> {
    if padding != RsaPadding::Pkcs1v15 {
        return Err("Private key encryption only supports PKCS1Padding".to_string());
    }
    let k = priv_key.size();
    let max_block = k
        .checked_sub(11)
        .filter(|block| *block > 0)
        .ok_or_else(|| "RSA key too small".to_string())?;
    let mut out = Vec::with_capacity((data.len() / max_block + 1) * k);
    for chunk in data
        .chunks(max_block)
        .chain(data.is_empty().then_some(&[][..]))
    {
        let em = build_pkcs1_type1_block(k, chunk)?;
        let m = rsa::BigUint::from_bytes_be(&em);
        let c = rsa::hazmat::rsa_decrypt(Some(&mut rand_core::OsRng), priv_key, &m)
            .map_err(|e| format!("RSA private encrypt failed: {}", e))?;
        let mut bytes = c.to_bytes_be();
        // 模运算可能丢失前导零，需补齐到模长
        if bytes.len() < k {
            let mut padded = vec![0u8; k - bytes.len()];
            padded.append(&mut bytes);
            bytes = padded;
        }
        out.extend_from_slice(&bytes);
    }
    Ok(out)
}

/// 公钥分段解密（对应私钥加密的密文，type 1 填充）
pub fn rsa_public_decrypt_segmented(
    pub_key: &RsaPublicKey,
    padding: RsaPadding,
    data: &[u8],
) -> Result<Vec<u8>, String> {
    if padding != RsaPadding::Pkcs1v15 {
        return Err("Public key decryption only supports PKCS1Padding".to_string());
    }
    let k = pub_key.size();
    if k == 0 || data.is_empty() || !data.len().is_multiple_of(k) {
        return Err(format!(
            "Ciphertext length {} is not a multiple of RSA key size {}",
            data.len(),
            k
        ));
    }
    let mut out = Vec::new();
    for block in data.chunks(k) {
        let c = rsa::BigUint::from_bytes_be(block);
        let m = rsa::hazmat::rsa_encrypt(pub_key, &c)
            .map_err(|e| format!("RSA public decrypt failed: {}", e))?;
        let mut em = m.to_bytes_be();
        if em.len() < k {
            let mut padded = vec![0u8; k - em.len()];
            padded.append(&mut em);
            em = padded;
        }
        out.extend_from_slice(&strip_pkcs1_type1_block(&em)?);
    }
    Ok(out)
}

/// 构造 PKCS#1 v1.5 type 1 块：0x00 0x01 [0xFF...] 0x00 [data]
fn build_pkcs1_type1_block(k: usize, data: &[u8]) -> Result<Vec<u8>, String> {
    if data.len() + 11 > k {
        return Err("Data too long for RSA key".to_string());
    }
    let mut em = vec![0u8; k];
    em[1] = 0x01;
    em[2..k - data.len() - 1].fill(0xFF);
    em[k - data.len() - 1] = 0x00;
    em[k - data.len()..].copy_from_slice(data);
    Ok(em)
}

/// 剥离 PKCS#1 v1.5 type 1 填充，返回原始数据
fn strip_pkcs1_type1_block(em: &[u8]) -> Result<Vec<u8>, String> {
    if em.len() < 11 || em[0] != 0x00 || em[1] != 0x01 {
        return Err("Bad PKCS#1 type 1 padding".to_string());
    }
    for (i, b) in em[2..].iter().enumerate() {
        if *b == 0x00 {
            if i < 8 {
                return Err("Bad PKCS#1 type 1 padding".into());
            }
            return Ok(em[i + 3..].to_vec());
        }
        if *b != 0xFF {
            return Err("Bad PKCS#1 type 1 padding".to_string());
        }
    }
    Err("Bad PKCS#1 type 1 padding".to_string())
}

/// 加密分块上限（对齐 hutool：PKCS1 = k-11，OAEP-SHA1 = k-42，OAEP-SHA256 = k-66）
fn max_encrypt_block(k: usize, padding: RsaPadding) -> Result<usize, String> {
    let overhead = match padding {
        RsaPadding::Pkcs1v15 => 11,
        RsaPadding::OaepSha1 => 42,
        RsaPadding::OaepSha256 => 66,
    };
    k.checked_sub(overhead)
        .filter(|b| *b > 0)
        .ok_or_else(|| "RSA key too small for selected padding".to_string())
}

// ---------------------------------------------------------------------------
// 签名 / 验签（对齐 hutool Sign）
// ---------------------------------------------------------------------------

/// 签名摘要算法
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SignAlgo {
    Md5,
    Sha1,
    Sha224,
    Sha256,
    Sha384,
    Sha512,
}

/// 解析签名算法，如 "SHA256withRSA"、"SHA1withRSA"、"MD5withRSA"（大小写不敏感）
pub fn parse_sign_algorithm(algorithm: &str) -> Result<SignAlgo, String> {
    let up = algorithm.trim().to_ascii_uppercase();
    let head = up.strip_suffix("WITHRSA").unwrap_or(&up);
    match head {
        "MD5" => Ok(SignAlgo::Md5),
        "SHA1" | "SHA-1" => Ok(SignAlgo::Sha1),
        "SHA224" | "SHA-224" => Ok(SignAlgo::Sha224),
        "SHA256" | "SHA-256" => Ok(SignAlgo::Sha256),
        "SHA384" | "SHA-384" => Ok(SignAlgo::Sha384),
        "SHA512" | "SHA-512" => Ok(SignAlgo::Sha512),
        _ => Err(format!(
            "Unsupported sign algorithm: {} (supported: MD5/SHA1/SHA224/SHA256/SHA384/SHA512 with RSA)",
            algorithm
        )),
    }
}

/// 每个签名会话只保留固定大小摘要状态，不在Rust中累计无界正文。
pub(super) fn sign_digest(algo: SignAlgo) -> Box<dyn sha2::digest::DynDigest> {
    match algo {
        SignAlgo::Md5 => Box::new(md5::Md5::default()),
        SignAlgo::Sha1 => Box::new(sha1::Sha1::default()),
        SignAlgo::Sha224 => Box::new(sha2::Sha224::default()),
        SignAlgo::Sha256 => Box::new(sha2::Sha256::default()),
        SignAlgo::Sha384 => Box::new(sha2::Sha384::default()),
        SignAlgo::Sha512 => Box::new(sha2::Sha512::default()),
    }
}
fn sign_padding(algo: SignAlgo) -> Pkcs1v15Sign {
    match algo {
        SignAlgo::Md5 => Pkcs1v15Sign::new::<md5::Md5>(),
        SignAlgo::Sha1 => Pkcs1v15Sign::new::<sha1::Sha1>(),
        SignAlgo::Sha224 => Pkcs1v15Sign::new::<sha2::Sha224>(),
        SignAlgo::Sha256 => Pkcs1v15Sign::new::<sha2::Sha256>(),
        SignAlgo::Sha384 => Pkcs1v15Sign::new::<sha2::Sha384>(),
        SignAlgo::Sha512 => Pkcs1v15Sign::new::<sha2::Sha512>(),
    }
}
/// 带盲化的私钥计算不改变PKCS1 v1.5签名的确定性结果。
pub(super) fn rsa_sign_digest(
    algo: SignAlgo,
    key: &RsaPrivateKey,
    digest: &[u8],
) -> Result<Vec<u8>, String> {
    key.sign_with_rng(&mut rand_core::OsRng, sign_padding(algo), digest)
        .map_err(|e| format!("RSA sign failed: {e}"))
}
pub(super) fn rsa_verify_digest(
    algo: SignAlgo,
    key: &RsaPublicKey,
    digest: &[u8],
    sig: &[u8],
) -> bool {
    key.verify(sign_padding(algo), digest, sig).is_ok()
}
pub fn rsa_sign(algo: SignAlgo, key: &RsaPrivateKey, data: &[u8]) -> Result<Vec<u8>, String> {
    let mut digest = sign_digest(algo);
    digest.update(data);
    rsa_sign_digest(algo, key, &digest.finalize())
}
pub fn rsa_verify(algo: SignAlgo, key: &RsaPublicKey, data: &[u8], sig: &[u8]) -> bool {
    let mut digest = sign_digest(algo);
    digest.update(data);
    rsa_verify_digest(algo, key, &digest.finalize(), sig)
}

/// 密文/签名字符串按参考版先识别偶数Hex，不反复猜解码和解密格式。
fn decode_cipher_text(s: &str) -> Result<Vec<u8>, String> {
    if s.len().is_multiple_of(2) && s.bytes().all(|b| b.is_ascii_hexdigit()) {
        hex::decode(s).map_err(|e| e.to_string())
    } else {
        super::base64_codec::decode_hutool(s)
    }
}
fn js_err(msg: impl Into<String>) -> rquickjs::Error {
    rquickjs::Error::new_from_js_message("value", "RSA", msg.into())
}
/// 密钥字符串保留PEM/Base64扩展；字节路径直接解析DER，避免二次编解码。
pub(super) enum KeyArg {
    Text(String),
    Der(Vec<u8>),
}
impl<'js> FromJs<'js> for KeyArg {
    fn from_js(ctx: &rquickjs::Ctx<'js>, value: rquickjs::Value<'js>) -> rquickjs::Result<Self> {
        if value.is_array()
            || rquickjs::TypedArray::<u8>::from_value(value.clone()).is_ok()
            || rquickjs::TypedArray::<i8>::from_value(value.clone()).is_ok()
        {
            return Ok(Self::Der(ByteArray::from_js(ctx, value)?.0));
        }
        Ok(Self::Text(TextArg::from_js(ctx, value)?.0))
    }
}
impl KeyArg {
    pub(super) fn public(self) -> Result<RsaPublicKey, String> {
        use rsa::{pkcs1::DecodeRsaPublicKey, pkcs8::DecodePublicKey};
        match self {
            Self::Text(t) => parse_public_key(&t),
            Self::Der(b) => RsaPublicKey::from_public_key_der(&b)
                .or_else(|_| RsaPublicKey::from_pkcs1_der(&b))
                .map_err(|e| format!("Invalid RSA public DER: {e}")),
        }
    }
    pub(super) fn private(self) -> Result<RsaPrivateKey, String> {
        use rsa::{pkcs1::DecodeRsaPrivateKey, pkcs8::DecodePrivateKey};
        match self {
            Self::Text(t) => parse_private_key(&t),
            Self::Der(b) => RsaPrivateKey::from_pkcs8_der(&b)
                .or_else(|_| RsaPrivateKey::from_pkcs1_der(&b))
                .map_err(|e| format!("Invalid RSA private DER: {e}")),
        }
    }
}
/// 缺参走上游默认公钥；显式null走可空Boolean的私钥分支。
struct Direction(bool);
impl<'js> rquickjs::function::FromParam<'js> for Direction {
    fn param_requirement() -> rquickjs::function::ParamRequirement {
        rquickjs::function::ParamRequirement::optional()
    }
    fn from_param<'a>(
        p: &mut rquickjs::function::ParamsAccessor<'a, 'js>,
    ) -> rquickjs::Result<Self> {
        if p.is_empty() {
            return Ok(Self(true));
        }
        let v = p.arg();
        if v.is_null() {
            return Ok(Self(false));
        }
        Ok(Self(bool::from_js(p.ctx(), v)?))
    }
}
fn value_to_bytes(v: &rquickjs::Value<'_>) -> rquickjs::Result<Vec<u8>> {
    if let Some(s) = v.as_string() {
        return Ok(s.to_string()?.into_bytes());
    }
    Ok(ByteArray::from_js(v.ctx(), v.clone())?.0)
}
fn value_to_cipher_bytes(v: &rquickjs::Value<'_>) -> rquickjs::Result<Vec<u8>> {
    if let Some(s) = v.as_string() {
        return decode_cipher_text(&s.to_string()?).map_err(js_err);
    }
    Ok(ByteArray::from_js(v.ctx(), v.clone())?.0)
}

/// createAsymmetricCrypto 对象状态（对齐 Kotlin AsymmetricCrypto）
struct AsymState {
    padding: RsaPadding,
    public: Option<RsaPublicKey>,
    private: Option<RsaPrivateKey>,
}

impl AsymState {
    fn new(padding: RsaPadding) -> Self {
        Self {
            padding,
            public: None,
            private: None,
        }
    }

    /// 对齐 hutool：未提供任何密钥时生成随机 1024 位密钥对
    fn ensure_random_keys(&mut self) -> Result<(), String> {
        if self.public.is_none() && self.private.is_none() {
            let priv_key = RsaPrivateKey::new(&mut rand_core::OsRng, 1024)
                .map_err(|e| format!("Failed to generate random RSA key pair: {}", e))?;
            self.public = Some(RsaPublicKey::from(&priv_key));
            self.private = Some(priv_key);
        }
        Ok(())
    }

    fn public_key(&mut self) -> Result<RsaPublicKey, String> {
        self.ensure_random_keys()?;
        self.public
            .clone()
            .ok_or_else(|| "Missing RSA public key, call setPublicKey first".to_string())
    }

    fn private_key(&mut self) -> Result<RsaPrivateKey, String> {
        self.ensure_random_keys()?;
        self.private
            .clone()
            .ok_or_else(|| "Missing RSA private key, call setPrivateKey first".to_string())
    }

    /// 加解密方向分发（usePublicKey 对齐 Kotlin getKeyType）
    fn encrypt(&mut self, use_public: bool, data: &[u8]) -> Result<Vec<u8>, String> {
        if use_public {
            let key = self.public_key()?;
            rsa_encrypt_segmented(&key, self.padding, data)
        } else {
            let key = self.private_key()?;
            rsa_private_encrypt_segmented(&key, self.padding, data)
        }
    }

    fn decrypt(&mut self, use_public: bool, data: &[u8]) -> Result<Vec<u8>, String> {
        if use_public {
            let key = self.public_key()?;
            rsa_public_decrypt_segmented(&key, self.padding, data)
        } else {
            let key = self.private_key()?;
            rsa_decrypt_segmented(&key, self.padding, data)
        }
    }
}

/// 构造 createAsymmetricCrypto 返回的 JS 对象
///
/// 方法集合对齐 Kotlin `AsymmetricCrypto`：
/// setPublicKey / setPrivateKey / encrypt / encryptHex / encryptBase64 /
/// decrypt / decryptStr，均带可选 `usePublicKey`（默认 true，对齐 Kotlin 默认值）。
pub fn build_asymmetric_crypto_object<'js>(
    ctx: rquickjs::Ctx<'js>,
    transformation: &str,
) -> rquickjs::Result<rquickjs::Object<'js>> {
    let padding = parse_rsa_transformation(transformation).map_err(js_err)?;
    let state = Rc::new(RefCell::new(AsymState::new(padding)));
    let obj = rquickjs::Object::new(ctx.clone())?;

    // setPublicKey(key) -> this（链式调用；通过 This 参数返回，避免闭包捕获对象自身造成 GC 循环引用）
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |this: rquickjs::function::This<rquickjs::Object<'js>>,
                  key: KeyArg|
                  -> rquickjs::Result<rquickjs::Object<'js>> {
                let pk = key.public().map_err(js_err)?;
                st.borrow_mut().public = Some(pk);
                Ok(this.0)
            },
        )?;
        obj.set("setPublicKey", f)?;
    }

    // setPrivateKey(key) -> this（链式调用）
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |this: rquickjs::function::This<rquickjs::Object<'js>>,
                  key: KeyArg|
                  -> rquickjs::Result<rquickjs::Object<'js>> {
                let k = key.private().map_err(js_err)?;
                st.borrow_mut().private = Some(k);
                Ok(this.0)
            },
        )?;
        obj.set("setPrivateKey", f)?;
    }

    // encrypt(data, usePublicKey?) -> Uint8Array（对齐 Kotlin encrypt: ByteArray）
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |ctx: rquickjs::Ctx<'js>,
                  data: rquickjs::Value<'js>,
                  use_public: Direction|
                  -> rquickjs::Result<rquickjs::TypedArray<'js, u8>> {
                let bytes = value_to_bytes(&data)?;
                let ct = st
                    .borrow_mut()
                    .encrypt(use_public.0, &bytes)
                    .map_err(js_err)?;
                rquickjs::TypedArray::new(ctx.clone(), ct)
            },
        )?;
        obj.set("encrypt", f)?;
    }

    // encryptHex(data, usePublicKey?) -> String
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |data: rquickjs::Value<'js>, use_public: Direction| -> rquickjs::Result<String> {
                let bytes = value_to_bytes(&data)?;
                let ct = st
                    .borrow_mut()
                    .encrypt(use_public.0, &bytes)
                    .map_err(js_err)?;
                Ok(hex::encode(ct))
            },
        )?;
        obj.set("encryptHex", f)?;
    }

    // encryptBase64(data, usePublicKey?) -> String
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |data: rquickjs::Value<'js>, use_public: Direction| -> rquickjs::Result<String> {
                let bytes = value_to_bytes(&data)?;
                let ct = st
                    .borrow_mut()
                    .encrypt(use_public.0, &bytes)
                    .map_err(js_err)?;
                Ok(B64.encode(ct))
            },
        )?;
        obj.set("encryptBase64", f)?;
    }

    // decrypt(data, usePublicKey?) -> Uint8Array；格式在计算前确定一次。
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |ctx: rquickjs::Ctx<'js>,
                  data: rquickjs::Value<'js>,
                  use_public: Direction|
                  -> rquickjs::Result<rquickjs::TypedArray<'js, u8>> {
                let use_pub = use_public.0;
                let bytes = value_to_cipher_bytes(&data)?;
                let pt = st.borrow_mut().decrypt(use_pub, &bytes).map_err(js_err)?;
                rquickjs::TypedArray::new(ctx.clone(), pt)
            },
        )?;
        obj.set("decrypt", f)?;
    }

    // decryptStr(data, usePublicKey?) -> String
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |data: rquickjs::Value<'js>, use_public: Direction| -> rquickjs::Result<String> {
                let use_pub = use_public.0;
                let bytes = value_to_cipher_bytes(&data)?;
                let pt = st.borrow_mut().decrypt(use_pub, &bytes).map_err(js_err)?;
                Ok(String::from_utf8_lossy(&pt).into_owned())
            },
        )?;
        obj.set("decryptStr", f)?;
    }

    Ok(obj)
}

/// createSign 对象状态（对齐 Kotlin Sign / hutool Sign）
struct SignState {
    algo: SignAlgo,
    public: Option<RsaPublicKey>,
    private: Option<RsaPrivateKey>,
}

impl SignState {
    fn new(algo: SignAlgo) -> Self {
        Self {
            algo,
            public: None,
            private: None,
        }
    }

    fn sign(&mut self, data: &[u8]) -> Result<Vec<u8>, String> {
        let key = self
            .private
            .clone()
            .ok_or_else(|| "Missing private key for sign, call setPrivateKey first".to_string())?;
        rsa_sign(self.algo, &key, data)
    }

    fn verify(&mut self, data: &[u8], sig: &[u8]) -> Result<bool, String> {
        let key = self
            .public
            .clone()
            .ok_or_else(|| "Missing public key for verify, call setPublicKey first".to_string())?;
        Ok(rsa_verify(self.algo, &key, data, sig))
    }
}

/// 构造 createSign 返回的 JS 对象
///
/// 方法集合对齐 Kotlin `Sign`（hutool）：
/// setPrivateKey / setPublicKey / sign / signHex / signBase64 / verify。
pub fn build_sign_object<'js>(
    ctx: rquickjs::Ctx<'js>,
    algorithm: &str,
) -> rquickjs::Result<rquickjs::Object<'js>> {
    let algo = parse_sign_algorithm(algorithm).map_err(js_err)?;
    let state = Rc::new(RefCell::new(SignState::new(algo)));
    let obj = rquickjs::Object::new(ctx.clone())?;

    // setPrivateKey(key) -> this（通过 This 参数返回，避免 GC 循环引用）
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |this: rquickjs::function::This<rquickjs::Object<'js>>,
                  key: KeyArg|
                  -> rquickjs::Result<rquickjs::Object<'js>> {
                let k = key.private().map_err(js_err)?;
                st.borrow_mut().private = Some(k);
                Ok(this.0)
            },
        )?;
        obj.set("setPrivateKey", f)?;
    }

    // setPublicKey(key) -> this
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |this: rquickjs::function::This<rquickjs::Object<'js>>,
                  key: KeyArg|
                  -> rquickjs::Result<rquickjs::Object<'js>> {
                let pk = key.public().map_err(js_err)?;
                st.borrow_mut().public = Some(pk);
                Ok(this.0)
            },
        )?;
        obj.set("setPublicKey", f)?;
    }

    // sign(data) -> Uint8Array（对齐 hutool Sign.sign: byte[]）
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |ctx: rquickjs::Ctx<'js>,
                  data: rquickjs::Value<'js>|
                  -> rquickjs::Result<rquickjs::TypedArray<'js, u8>> {
                let bytes = value_to_bytes(&data)?;
                let sig = st.borrow_mut().sign(&bytes).map_err(js_err)?;
                rquickjs::TypedArray::new(ctx.clone(), sig)
            },
        )?;
        obj.set("sign", f)?;
    }

    // signHex(data) -> String（对齐 hutool Sign.signHex，WebJsExtensions 使用）
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |data: rquickjs::Value<'js>| -> rquickjs::Result<String> {
                let bytes = value_to_bytes(&data)?;
                let sig = st.borrow_mut().sign(&bytes).map_err(js_err)?;
                Ok(hex::encode(sig))
            },
        )?;
        obj.set("signHex", f)?;
    }

    // signBase64(data) -> String
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |data: rquickjs::Value<'js>| -> rquickjs::Result<String> {
                let bytes = value_to_bytes(&data)?;
                let sig = st.borrow_mut().sign(&bytes).map_err(js_err)?;
                Ok(B64.encode(sig))
            },
        )?;
        obj.set("signBase64", f)?;
    }

    // verify(data, sign) -> boolean；保留Hex/Base64字符串扩展，合法不匹配返回false。
    {
        let st = state.clone();
        let f = rquickjs::Function::new(
            ctx.clone(),
            move |data: rquickjs::Value<'js>,
                  sig: rquickjs::Value<'js>|
                  -> rquickjs::Result<bool> {
                let bytes = value_to_bytes(&data)?;
                let sig_bytes = value_to_cipher_bytes(&sig)?;
                st.borrow_mut().verify(&bytes, &sig_bytes).map_err(js_err)
            },
        )?;
        obj.set("verify", f)?;
    }

    Ok(obj)
}

// ---------------------------------------------------------------------------
// 测试辅助
// ---------------------------------------------------------------------------

/// 仅供测试：生成随机 1024 位密钥对，返回 (公钥 Base64 SPKI DER, 私钥 Base64 PKCS#8 DER)
#[cfg(test)]
pub fn generate_test_keypair_b64() -> (String, String) {
    use rsa::pkcs8::{EncodePrivateKey, EncodePublicKey};

    let priv_key = RsaPrivateKey::new(&mut rand_core::OsRng, 1024).expect("generate keypair");
    let pub_key = RsaPublicKey::from(&priv_key);
    let pub_der = pub_key.to_public_key_der().expect("encode public key");
    let priv_der = priv_key.to_pkcs8_der().expect("encode private key");
    (
        B64.encode(pub_der.as_bytes()),
        B64.encode(priv_der.as_bytes()),
    )
}

// ---------------------------------------------------------------------------
// 测试
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn test_keypair() -> (RsaPublicKey, RsaPrivateKey) {
        let priv_key = RsaPrivateKey::new(&mut rand_core::OsRng, 1024).unwrap();
        let pub_key = RsaPublicKey::from(&priv_key);
        (pub_key, priv_key)
    }

    // ---- transformation 解析 ----

    #[test]
    fn test_parse_rsa_transformation() {
        assert_eq!(
            parse_rsa_transformation("RSA").unwrap(),
            RsaPadding::Pkcs1v15
        );
        assert_eq!(
            parse_rsa_transformation("RSA/ECB/PKCS1Padding").unwrap(),
            RsaPadding::Pkcs1v15
        );
        assert_eq!(
            parse_rsa_transformation("RSA/None/PKCS1Padding").unwrap(),
            RsaPadding::Pkcs1v15
        );
        assert_eq!(
            parse_rsa_transformation("RSA/ECB/OAEPWithSHA-1AndMGF1Padding").unwrap(),
            RsaPadding::OaepSha1
        );
        assert_eq!(
            parse_rsa_transformation("RSA/ECB/OAEPWITHSHA256ANDMGF1PADDING").unwrap(),
            RsaPadding::OaepSha256
        );
        assert!(parse_rsa_transformation("RSA/ECB/NoPadding").is_err());
        assert!(parse_rsa_transformation("ECB").is_err());
    }

    // ---- 加解密往返 ----

    #[test]
    fn test_rsa_pkcs1_roundtrip() {
        let (pub_key, priv_key) = test_keypair();
        let data = b"Hello, Legado RSA!";
        let ct = rsa_encrypt_segmented(&pub_key, RsaPadding::Pkcs1v15, data).unwrap();
        let pt = rsa_decrypt_segmented(&priv_key, RsaPadding::Pkcs1v15, &ct).unwrap();
        assert_eq!(pt, data);
    }

    #[test]
    fn test_rsa_pkcs1_segmented_long_data() {
        // 300 字节超过 1024 位密钥单块上限（117），必须分段
        let (pub_key, priv_key) = test_keypair();
        let data: Vec<u8> = (0..300u32).map(|i| (i % 256) as u8).collect();
        let ct = rsa_encrypt_segmented(&pub_key, RsaPadding::Pkcs1v15, &data).unwrap();
        // 1024 位密钥：300/117 = 3 块，密文长 3*128
        assert_eq!(ct.len(), 3 * 128);
        let pt = rsa_decrypt_segmented(&priv_key, RsaPadding::Pkcs1v15, &ct).unwrap();
        assert_eq!(pt, data);
    }

    #[test]
    fn test_rsa_oaep_sha256_roundtrip() {
        let (pub_key, priv_key) = test_keypair();
        let data = b"OAEP roundtrip test";
        let ct = rsa_encrypt_segmented(&pub_key, RsaPadding::OaepSha256, data).unwrap();
        let pt = rsa_decrypt_segmented(&priv_key, RsaPadding::OaepSha256, &ct).unwrap();
        assert_eq!(pt, data);
    }

    #[test]
    fn test_rsa_private_encrypt_public_decrypt() {
        // 私钥加密 / 公钥解密（Java Cipher 反向用法）
        let (pub_key, priv_key) = test_keypair();
        let data = b"private key encrypt direction";
        let ct = rsa_private_encrypt_segmented(&priv_key, RsaPadding::Pkcs1v15, data).unwrap();
        let pt = rsa_public_decrypt_segmented(&pub_key, RsaPadding::Pkcs1v15, &ct).unwrap();
        assert_eq!(pt, data);
    }

    #[test]
    fn test_rsa_wrong_key_decrypt_fails() {
        let (pub_key, _) = test_keypair();
        let (_, other_priv) = test_keypair();
        let ct = rsa_encrypt_segmented(&pub_key, RsaPadding::Pkcs1v15, b"secret").unwrap();
        assert!(rsa_decrypt_segmented(&other_priv, RsaPadding::Pkcs1v15, &ct).is_err());
    }

    #[test]
    fn test_rsa_decrypt_bad_length_fails() {
        let (_, priv_key) = test_keypair();
        assert!(rsa_decrypt_segmented(&priv_key, RsaPadding::Pkcs1v15, &[1, 2, 3]).is_err());
    }

    // ---- 密钥解析 ----

    #[test]
    fn test_parse_keys_from_base64_der() {
        let (pub_b64, priv_b64) = generate_test_keypair_b64();
        let pub_key = parse_public_key(&pub_b64).unwrap();
        let priv_key = parse_private_key(&priv_b64).unwrap();
        // 解析出的密钥可用于加解密往返
        let ct = rsa_encrypt_segmented(&pub_key, RsaPadding::Pkcs1v15, b"der keys").unwrap();
        let pt = rsa_decrypt_segmented(&priv_key, RsaPadding::Pkcs1v15, &ct).unwrap();
        assert_eq!(pt, b"der keys");
    }

    #[test]
    fn test_parse_private_key_from_pem() {
        use rsa::pkcs8::{EncodePrivateKey, LineEnding};
        let (_, priv_key) = test_keypair();
        let pem = priv_key.to_pkcs8_pem(LineEnding::LF).unwrap();
        let parsed = parse_private_key(&pem).unwrap();
        assert_eq!(parsed.size(), priv_key.size());
    }

    #[test]
    fn test_parse_invalid_key_fails() {
        assert!(parse_public_key("not a key at all!!!").is_err());
        assert!(
            parse_private_key("-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----")
                .is_err()
        );
    }

    // ---- 签名验签 ----

    #[test]
    fn test_parse_sign_algorithm() {
        assert_eq!(
            parse_sign_algorithm("SHA256withRSA").unwrap(),
            SignAlgo::Sha256
        );
        assert_eq!(parse_sign_algorithm("sha1withrsa").unwrap(), SignAlgo::Sha1);
        assert_eq!(parse_sign_algorithm("MD5withRSA").unwrap(), SignAlgo::Md5);
        assert!(parse_sign_algorithm("SHA3withRSA").is_err());
    }

    #[test]
    fn test_rsa_sign_verify_roundtrip() {
        let (pub_key, priv_key) = test_keypair();
        let data = b"data to be signed";
        for algo in [
            SignAlgo::Md5,
            SignAlgo::Sha1,
            SignAlgo::Sha224,
            SignAlgo::Sha256,
            SignAlgo::Sha384,
            SignAlgo::Sha512,
        ] {
            let sig = rsa_sign(algo, &priv_key, data).unwrap();
            assert!(rsa_verify(algo, &pub_key, data, &sig), "algo: {:?}", algo);
            // 篡改数据应验签失败
            assert!(!rsa_verify(algo, &pub_key, b"tampered", &sig));
        }
    }

    #[test]
    fn test_rsa_verify_wrong_key_fails() {
        let (_, priv_key) = test_keypair();
        let (other_pub, _) = test_keypair();
        let sig = rsa_sign(SignAlgo::Sha256, &priv_key, b"data").unwrap();
        assert!(!rsa_verify(SignAlgo::Sha256, &other_pub, b"data", &sig));
    }

    // ---- 状态对象（随机密钥生成路径）----

    #[test]
    fn test_asym_state_random_keys_roundtrip() {
        // 对齐 hutool：未设置密钥时生成随机密钥对，加解密应自洽
        let mut st = AsymState::new(RsaPadding::Pkcs1v15);
        let ct = st.encrypt(true, b"random pair test").unwrap();
        let pt = st.decrypt(false, &ct).unwrap();
        assert_eq!(pt, b"random pair test");
    }

    #[test]
    fn test_decode_cipher_text_base64_and_hex() {
        // 先识别偶数Hex，其余复用既有Base64策略。
        assert_eq!(decode_cipher_text("aGVsbG8=").unwrap(), b"hello");
        assert_eq!(decode_cipher_text("68656c6c6f").unwrap(), b"hello");
        assert!(decode_cipher_text("~").is_err());
        assert!(decode_cipher_text("中").unwrap().is_empty());
        assert!(decode_cipher_text("###").unwrap().is_empty());
    }
}
