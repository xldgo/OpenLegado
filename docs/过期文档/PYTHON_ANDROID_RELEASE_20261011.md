# Android Release APK 校验与收集

本文保存 `PYTHON-APK-20261011` 的命令、行为和未测边界，任务状态只记录于
[Active 计划](REFACTORING_ACTIVE_PLAN.md)。基线提交为 `e5798a701`，
分支为 `feature/ui-android-release-artifacts`，实现提交为 `2bbd0019e`。

## 收口范围

`android-release.yml` 原来内嵌另一份 APK ZIP/NDK strip/SHA 校验与复制逻辑。
现在 workflow 调用根 CLI，复用 `scripts/tooling/android_app.py` 的 APK 校验器，
保留现有 Flutter 分 ABI 构建步骤和上传、发布契约。

正式 Release 继续生成 `arm64-v8a`、`armeabi-v7a`、`x86_64` 三个包；QuickJS 策略仍来自
`android-policy.json`，armv7 预先关闭 QuickJS，其他两 ABI 开启。SDK、Java 17、NDK、Rust stable、
Flutter/FRB 版本以及应用版本 `2.0.369+370` 均不变。

## 命令

从仓库根目录执行：

```powershell
# 校验并收集已经生成的三个分 ABI Release APK，不重新编译
python scripts/dev.py collect apk android --profile release --abis arm64-v8a,armeabi-v7a,x86_64 --output-dir release-apk --cargo-target-dir rust/target

# 单独只读校验某个分 ABI APK，同时核对 Cargo 来源
python scripts/dev.py verify apk android --profile release --abis arm64-v8a --apk flutter_legado/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk --cargo-target-dir rust/target
```

收集命令根据明确的 profile/ABI 从 `flutter_legado/build/app/outputs/flutter-apk/` 读取
`app-<abi>-<profile>.apk`，保持文件名复制到 `--output-dir`。它不编译、不安装、不上传，也不创建 Release。
未指定 Cargo 目录时仍核对源库，按 `CARGO_TARGET_DIR` 或 `rust/target` 定位；显式相对路径相对调用目录。
`--ndk` 可指定策略要求的 NDK，发现和版本检查复用现有代码。

`--output-dir` 相对调用目录，解析后必须位于仓库内的专用子目录；不能包含或嵌套在 APK 输入目录，
不能位于 Rust/工具源码或 Git/Agent 配置目录。输出目录必须为空，或仅包含本次明确请求的 APK 文件。
遇到其他文件、其他 ABI/profile 残留或子目录时返回失败，不自动清理。默认 `release-apk/` 已忽略。

## 校验与失败行为

1. 对每个 ABI 调用现有严格 FFI 校验：Dart/Rust 契约、源码与工具指纹、ABI/profile/features、
   v2 元数据、jniLibs 摘要及 Cargo 源库摘要均须匹配。
2. ZIP 中 `lib/<abi>/liblegado_ffi.so` 必须完整且唯一；缺失、重复或混入其他 Rust 库 ABI 均失败。
3. APK 库、jniLibs 库，以及显式核对的 Cargo 源库都复制到临时目录，用同一 NDK `llvm-strip --strip-unneeded`
   正规化后比较摘要。这保留了原 CI 直接比较 Cargo 与 APK 的门禁，并与本地 APK 检查共用实现。
   不修改输入 APK、jniLibs 或 Cargo 库；合法 strip 差异仍可接受。
4. 全部输入 APK 先通过校验，检查校验前后完整文件摘要不变，再暂存全部包并核对复制摘要。
   暂存包须与已校验原件的完整摘要一致，发布前再核对全部 native 输入；不重复解包或 strip 同一个包。
   预检或暂存失败时不改已有输出，不能因为前两个 ABI 通过就交付部分文件集。
5. 发布使用逐文件原子替换；不承诺整组文件的事务原子性。替换过程中发生 IO 错误或进程中断，
   输出可能部分更新，命令不会报告成功；下次必须重新执行完整收集。CI 步骤失败后不会执行正常上传或发布。

源码指纹、元数据和文件摘要证明构建输入/复制/打包的一致性，不能替代真实 Flutter FFI 加载与调用。
工具实现改动会使先前 native 元数据的输入摘要失效，下次应按当前入口重编，不为旧库补写新指纹。

## CI 保持的契约

- `v*` Tag 触发构建并发布；手动仅构建。
- `build` / `publish` 的依赖、权限和取消规则保持。
- `upload-apk` 的 Artifact ID 继续传给 publish；重跑 publish 不按新的 run attempt 猜测工件。
- 工件仍为 `android-apk-${run_id}-${run_attempt}`，目录与发布匹配仍为 `release-apk/*-release.apk`，保留 14 天。
- 删除只供原内嵌校验使用的 `NDK_TOOLCHAIN` 环境变量；统一工具继续从已有 NDK 配置定位 strip。

## 证据与未测边界

本轮主代理执行，不使用子代理。按用户要求，未运行 Python 测试、actionlint、Gradle、Cargo、
Flutter、设备或任何 CI。新增 11 项收集 fixture、一项 CLI 参数用例和一项 workflow 接线用例，
覆盖三 ABI、缺包、错 ABI、源库缺失、strip 合法差异、复制失败、输入变化和路径保护，但均未执行。
静态复核不代表最终 APK、NDK strip 或真实发布链路已通过；本轮没有新的 Actions URL 或设备证据。

提交/push 使用 `[skip ci]`，只推任务分支，不改 dev/master；iOS 内嵌工具、doctor 和其余旧入口另批整理。

## 回滚

仅回退本批 Android Release 接线即可恢复基线内嵌校验与收集步骤；新增 CLI/收集函数可独立撤回。
没有应用数据、FFI 协议或签名迁移。回滚工具实现后，现有输入摘要仍可能失效，重新构建 native 库，
不通过改写元数据绕过门禁。

编写者：Codex｜2026-10-11
