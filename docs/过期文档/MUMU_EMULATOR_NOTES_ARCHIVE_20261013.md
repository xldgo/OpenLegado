# MuMu 模拟器历史配置与实操记录归档（2026-10-13 移出 AGENTS.md）

> 归档说明：2026-10-13 起项目切换至官方 Android SDK 模拟器 `Legado_API_36`（API 36 `google_apis/x86_64`），原 `AGENTS.md` 中关于 MuMu 模拟器的配置、ROM 限制及历史故障诊断记录移入本文档留存备查。

## 原 `AGENTS.md` 模拟器验证档历史记录

- **模拟器验证档（2026-09-20 用户指令：改用 MuMu，弃用雷电）**：
  - **测试档 = MuMu 模拟器的「Test测试」实例**（guest 直连端点 **`192.168.1.19:5555`**，Android 15；该实例装有我方 `io.legado.flutter_legado`、原版 `com.legado.app.release`、**参考版 `io.legato.kazusa`** 三包，可做双/三包拓扑与参考采集）。启动：`"D:\Program Files\MuMuPlayer\nx_main\MuMuManager.exe" control -v 1 launch`（实例 index 1；`info -v all` 可查状态，`is_android_started` 为真后再 adb 连接；`127.0.0.1:16384/16416` 端点已失效，**只认 guest 直连**）。
  - **雷电模拟器彻底弃用（用户指令 2026-09-20）**：不修复 5556（LDPlayer 实例 1 环境故障）、不再使用 5554 临时档。**测试与用户实测验收统一使用上述 MuMu「Test测试」实例**（同一台机做自测与验收，三包同机便于拓扑对比）。
  - **冒烟脚本**（构建+安装+启动+崩溃检查）：`.\scripts\emulator_smoke_test.ps1 -Device 192.168.1.19:5555`（可加 `-CheckUI` 做书架主界面元素检查；复用 APK 加 `-SkipBuild`）；退出码 0=通过 1=失败。
  - **第二车道 = MuMu 实例 index 0「test2」（2026-09-20 用户开通并改名，用于并行设备任务）** → 端点 **`127.0.0.1:16384`**（宿主转发；与 Test 的 guest 直连端点不同）。已由主代理配置为**与 Test 同规格**：`wm size 1080x1920`、`wm density 480`（物理 720x1280，**override 不持久**，实例重启后需重跑这两条），并已装齐三包（我方 / 原版 3.26082823 / 参考版 kazusa 3.26.15）。**用途**：与 Test 并行跑设备任务（参考采集、双/三包对比、独立验证），避免单机串行；**Test 仍是主验证档**（自测与用户验收语义不变）。
  - **MuMu ROM 限制与绕行（2026-09-20 实测 + 用户侧复核，派任务前必读）**：设备伪装三星 SM-G9900/Android 15，模拟器特征 prop 全空。**中文输入三条绕行路径（不要再撞 IME）**：① 批量书源验证走 FFI/example——`cargo run --release --example scan_search_sources -- <db> @关键词文件(UTF-8 无 BOM) <报告.json>`（全程不碰模拟器）；② 走 UI 时把中文注入 `search_keywords`（该机 **adbd 即 root**、自带 sqlite3 3.44.3，`/data/data/<pkg>/app_flutter/legado.db` 直写；写完退出搜索页再进即刷新，不必 force-stop；WAL 下勿高频外部连接）；③ Flutter 测试内 `tester.enterText()` 直进引擎、绕过系统 IME。其余限制：IME enable/set 被安全策略 patch（但 **2026-09-21 实测 `input text` 可注入中文**，早前"仅 ASCII"的记录作废）；`cmd clipboard` 有命令但空实现（`service call clipboard` 可通但构造 ClipData 过繁、不值得走）；`screencap` 不能写 `/sdcard`（用 `exec-out screencap -p`）；`uiautomator` 写转储后自杀（噪声）；`content` 与 toybox `grep` 段错误（改本地解析）；`settings put secure` 静默回滚（用 `global`）；logcat 被 `E MESA: Failed to find VkFence` 刷屏。
  - **⚠ 设备档当前不可用（2026-09-24 实测，恢复前派设备任务=白跑）**：MuMu 实例（index 0「Test2」）**guest 内只有 `lo`、没有任何网络接口** → 现象三连：① **guest 无外网**（`ping` 报 `Network is unreachable`，真实书源/本地 mock 全不可达）；② **adb 报 `offline`**（16384/5555 端口在监听、TCP 可连，但 adbd 握手不完成；`adb kill-server`/换 MuMu 自带 adb/重启实例均**无效**）；③ **guest 直连端点 `192.168.1.19:5555` 不可达**。**宿主侧证据**：`Get-NetAdapter -IncludeHidden` 里**没有 MuMu/Hyper-V 虚拟交换机**（只有 WLAN/以太网/Radmin VPN/WAN Miniport），服务里只有 `HvHost`+`MuMuRemoteService`、**没有 `vmms`**（而 MuMu 报 `hyperv_enabled=true`）→ 判定为**宿主虚拟网络组件丢失**，需用户侧修复（MuMu 设置内的网络/修复、重装 MuMu 驱动组件，或启用 Hyper-V 平台并重建 vSwitch——均需管理员/可能需重启）。**诊断配方（不经 adb）**：`MuMuManager.exe sh --vmindex 0 --cmd "getprop init.svc.adbd; ip addr show; ping -c 2 -W 2 223.5.5.5"`（adbd 显示 running 但只有 `lo` 即命中本故障）。
  - **MuMu 实操补充（2026-09-23 实测，设备任务派单前必读）**：① **实例↔端点映射会漂**——当日实例 index 0「Test2」的 adb 端口为 **16384**（同 guest adbd 另有 `127.0.0.1:5555` 暴露为 `emulator-5554`，两者是**同一台 guest 的两条路径**，可用「设备侧写标记 → 从另一端点读回」验证）；index 1「Test测试」当时**未运行**（16416 连接拒绝），故设备任务须**先用 `MuMuManager.exe info -v all` 判定在线实例**，不要假设 5555/16384 恒可用。② **多屏/逻辑 display**：应用窗口挂在独立逻辑 display 上，其 id 每次 `force-stop` 后**会变**——输入须 `input -d <logicalId> tap/…`，截图须 `exec-out screencap -p -d <SF displayId>`（直接 `screencap` 会把设备端 warning 文本混入 stdout 损坏 PNG）。③ **`run-as sqlite3` 直写 DB 要求包可调试**：release 变体报 `package not debuggable`，种子/注入类验证须装 **debug 变体**（同 Dart 代码、同版本号），并在证据里注明变体与是否发生 Rust 重建（`.so` mtime）。④ 我方应用语义文本在 **`content-desc`**（Flutter 语义树），不在 `text` 属性——dump 核实须读 content-desc。
  - **端点时效性（2026-09-27 补充）**：本节及历史文档所载端点/IP/端口（含 `192.168.1.19:5555`、`192.168.100.63:5555`、`127.0.0.1:16384/16416` 等）均为**记录时点的历史事实**，会随宿主网段（NAT 子网漂移）与实例运行状态变化；每次设备任务前必须以 `MuMuManager.exe info -v all` 与 adb 实测探测为准，**不得把固定端点或旧设备可用记录当作当前可用保证**。

## 相关历史修订记录

- 修订：ZCode（本机 27B 通道）｜ 2026-09-20（**模拟器验证档改用 MuMu「Test测试」实例并用其统一承担自测与用户验收**：guest 直连 `192.168.1.19:5555`、MuMuManager 启动方式与端点失效说明、ROM 限制清单入档；雷电 5556 不再修复、5554 与 5558 档位一并废弃）
- 修订：ZCode ｜ 2026-09-24（**设备档停用告警入档**：MuMu guest 仅 `lo`、宿主缺虚拟交换机与 `vmms` → 无外网 + adb 恒 offline，附不经 adb 的诊断配方；恢复前不派设备任务）
- 修订：ZCode ｜ 2026-09-23（**MuMu 实操补充入档**：实例↔端点映射会漂（须先 `MuMuManager info -v all` 判定在线实例；index 0 的 adb 端口 16384 与 `emulator-5554` 是同一 guest 的两条路径）、多屏逻辑 display id 会变（输入 `input -d`、截图 `exec-out screencap -d`）、`run-as sqlite3` 种子须装 debug 变体、语义文本在 `content-desc`）

编写者：Pi 主代理 ｜ 2026-10-13
