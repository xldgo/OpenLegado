# Rust 依赖与产物下载 Action 升级

本批从 `2caf25afe` 创建 `feature/rust-dependency-upgrades`，按用户授权合为一个
带 `[skip ci]` 的提交。当前任务状态只维护于 [Active 计划](REFACTORING_ACTIVE_PLAN.md)
的 `RUST-DEPS-20261011`。Flutter 依赖与生成物、FRB 2.13.0、Rust stable、应用版本
`2.0.369+370`、数据库 schema 和现有功能保持。

## 版本范围

| 依赖 | 原锁定版本 | 本批目标 |
|---|---|---|
| actions/download-artifact | v4 | v8 |
| rusqlite | 0.31.0 | 0.40.2 |
| r2d2_sqlite | 0.24.0 | 0.35.0 |
| reqwest | 0.12.28 | 0.13.5 |
| zip | 2.4.2 | 9.0.1 |
| scraper | 0.22.0 | 0.27.0 |
| ego-tree | 0.10.0 | 0.11.0 |
| lru | 0.12.5 | 0.18.5 |
| md5 | 0.7.0 | 0.8.1 |

同步修改所有直接消费者的 Cargo 声明，以原 lockfile 为基础解析上述依赖及必要
传递依赖，不对剩余 Rust 库执行全量更新。`md5` 与 RustCrypto 的 `md-5` 是不同
包，本批保留 RSA/签名使用的旧 RustCrypto 兼容组。

`genpdf 0.2.0` 的图片接口直接使用 `image ^0.23.12` 的类型。保持这对依赖，
后续若升级图片/PDF 链，需要另行评估上游替代及输出兼容，本批不更换 PDF 引擎。

## 必要兼容处理

- r2d2_sqlite 0.35 使用 rusqlite 0.40；数据库与 FFI 直接依赖配套更新，避免两个
  libsqlite3-sys 同时声明 SQLite 原生链接。现有数据库迁移和数据格式保持。
- scraper 0.27 使用 ego-tree 0.11；CSS 与 XPath 共享的 HTML 树类型同步。
- reqwest 0.13 的 `rustls` 默认切换平台证书校验，Android 需要额外 JVM/Kotlin
  接线。现有 Dart FFI 宿主保留原 Mozilla 根证书与 ring 后端，通过统一客户端
  构造入口供网络层和服务层使用。自定义 CA、unsafeSSL、代理和 hosts 设置继续
  使用 ClientBuilder 的公开方法；证书校验默认开启。
- 显式启用 reqwest 的 `rustls-no-provider`，沿用 rustls 0.23 的 ring provider；
  `webpki-root-certs 1.0.9` 提供完整根证书 DER，以公开 `tls_certs_only` 接线。
  不使用不稳定的预配置 TLS 类型接口，也不新增 Android JNI 接口。
- download-artifact v8 保留原 artifact ID、目录与合并设置，接受默认摘要不匹配
  即失败的行为，上传仍使用 v7。

## 验证方法与边界

复用受影响模块的 Rust 测试，覆盖数据库升级与保留数据、CSS/XPath、EPUB/压缩、
缓存及 MD5、Cookie/代理/hosts；TLS 使用本地 HTTPS 服务覆盖默认拒绝不可信证书、
显式 unsafeSSL、自定义 CA 与主机名校验。QuickJS 的 ZIP/HTML/LRU 路径另做定向
回归。只构建 Android x86_64，检查本次库的来源及 LOAD/RELRO，再运行 MuMu FFI
冒烟；保留用户数据并恢复正常应用。Action 使用 actionlint 检查。

不运行整套 CI，不编译其他 Android ABI；MuMu 的 4 KB 页结果不替代 16 KB 设备
验证，也不扩大为 iOS/其他平台已经通过。

## 已取得的验证证据

- 受影响基础模块的 release 测试：book 160、core 817、db 325、数据库集成 5、
  net 258、HTTPS 握手 4、parser 320，共 1,889 项通过。
- QuickJS 定向回归：压缩 23、LRU 15、HTML 18、真实 jsoup 调用 3、摘要调用 2，
  共 61 项通过。以上合计 1,950 项；不声明 Rust 工作区全量门禁已通过。
- 初次编译发现 rusqlite 不再从 SQL 直接读取 usize，已改为 i64 后检查转换；
  zip 9 的条目名返回 Result/Cow，已同步错误传播与所有消费者，并通过上述回归。
- NDK 28.2.13676358 的一次 x86_64 release QuickJS 编译完成，耗时 3 分 35 秒，
  未复用旧库。原始库与 strip 后库通过 LOAD/RELRO 16 KB 校验，四个 LOAD 的
  对齐均为 16384；源码指纹与复制摘要吻合。
- 源码指纹：`6616debf5943f7fd09020b13eccaea2a7344346af7cd6240f2c7f532630f0062`。
  原始库 SHA256：`d685a428282f83ea0f26ecf14fbb5ebf0578c4b335e800c60ddd7a54df705de9`。
  strip 后 SHA256：`e508a599e1f8c60cbc50de72953648f1928939e0ff877c0be63ca38025091b66`。
- 测试 APK 的 x86_64 库与当前 Cargo 库经同一 NDK strip 正规化后摘要相同，
  APK SHA256：`1a62e9e60c108979b32ab02b96cad4e5fe269231805ff35f6389eac5000e6a26`。
  APK 仅用于 x86_64 冒烟；保留的其他 ABI 库未更新，不作为发布包交付。
- MuMu Android 15 / x86_64 / 4 KB 页，实测端点 `127.0.0.1:16384`：初始化、
  版本读取、真实书源数据库查询三项 FFI 通过。随后恢复已备份正常 APK，版本
  2.0.369 / code 4370，启动及崩溃检查通过；未卸载或清除数据。
- actionlint 与 `git diff --check` 通过。自审确认 SQLite
  原生链接仅一个版本、八项目标依赖均进入锁文件，Flutter 与 FRB 生成物无差异；
  不使用子代理，也不声称取得独立审查结论。

本地日志位于 worktree 的忽略目录 `.tmp_agp9_tools/`：
`rust-deps-core-tests.log`、`rust-deps-js-tests.log`、`rust-deps-native-x86.log`、
`rust-deps-native-verify.log`、`rust-deps-apk-verify.log`、`rust-deps-mumu-ffi.log`、
`rust-deps-mumu-restore.log`。它们仅用于本机复核，不写入提交正文。

## 来源

- [download-artifact v8 输入与行为](https://github.com/actions/download-artifact/tree/v8)
- [reqwest 0.13.5 features](https://docs.rs/reqwest/0.13.5/reqwest/#optional-features)
- [reqwest ClientBuilder TLS 接口](https://docs.rs/reqwest/0.13.5/reqwest/struct.ClientBuilder.html)
- [Android 平台证书校验初始化要求](https://docs.rs/rustls-platform-verifier/0.7.1/rustls_platform_verifier/android/index.html)
- [Mozilla 根证书 DER](https://docs.rs/webpki-root-certs/1.0.9/webpki_root_certs/)
- [r2d2_sqlite 0.35 依赖](https://crates.io/crates/r2d2_sqlite/0.35.0/dependencies)
- [scraper 0.27 依赖](https://crates.io/crates/scraper/0.27.0/dependencies)
- [genpdf 0.2 图片约束](https://crates.io/crates/genpdf/0.2.0/dependencies)

编写者：Codex｜2026-10-11
