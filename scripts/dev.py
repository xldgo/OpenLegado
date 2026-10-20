#!/usr/bin/env python3
"""仓库工程命令入口：生成代码、原生构建与运行、计算指纹和只读校验。"""

import sys

# Windows 重定向输出可能默认使用 cp1252；工程日志与错误统一输出 UTF-8。
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

# 只读命令也不在源码目录生成 Python 字节码缓存。
sys.dont_write_bytecode = True
if sys.version_info < (3, 11):
    print("错误：工程工具需要 Python 3.11 或更新版本。", file=sys.stderr)
    sys.exit(1)

import argparse
import os
from pathlib import Path
import unittest

from tooling.common import CommandError, ToolError, parse_abis


ROOT = Path(__file__).resolve().parents[1]


def report_error(error):
    print(f"错误：{error}", file=sys.stderr)
    if os.environ.get("GITHUB_ACTIONS") == "true":
        # 在检查页面保留具体失败原因；转义消息，避免内容被解释为新命令。
        message = str(error).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print(f"::error::{message}", file=sys.stderr)


def android_options(parser, build=False):
    parser.add_argument("--profile", choices=("debug", "release"), required=True)
    parser.add_argument("--abis", type=parse_abis, required=True, help="逗号分隔的 Android ABI")
    parser.add_argument("--cargo-target-dir", type=Path, help="显式指定或核对 Cargo 输出目录")
    if build:
        parser.add_argument("--ndk", type=Path, help="显式指定策略要求版本的 NDK")


def windows_options(parser, build=False):
    parser.add_argument("--profile", choices=("debug", "release"), required=True)
    parser.add_argument("--cargo-target-dir", type=Path, help="显式指定或核对 Cargo 输出目录")
    parser.add_argument("--no-quickjs", action="store_true", help="仅显式 Debug stub 开发；Release 禁止")
    if build:
        parser.add_argument("--clean", action="store_true", help="清理 legado-ffi 当前 target，应用命令也执行 flutter clean")


def ios_options(parser):
    parser.add_argument("--target", choices=("device", "simulator"), required=True)
    parser.add_argument("--profile", choices=("release",), required=True, help="正式 Rust 静态库使用 Release，宿主模式由 Flutter 决定")
    parser.add_argument("--cargo-target-dir", type=Path, help="显式指定或核对 Cargo 输出目录")


def main(argv=None):
    parser = argparse.ArgumentParser(description="OpenLegado 工程工具（Python 3.11+）")
    commands = parser.add_subparsers(dest="command", required=True)
    fingerprint = commands.add_parser("fingerprint", help="计算源码指纹")
    fingerprint.add_argument("component", choices=("rust",))
    generate = commands.add_parser("generate", help="生成 Dart 或 FRB 绑定，不重编应用")
    generators = generate.add_subparsers(dest="component", required=True)
    dart_generate = generators.add_parser("dart", help="按锁文件执行 Dart build_runner")
    dart_generate.add_argument("--check", action="store_true", help="隔离复核Dart生成物，不修改原工作区")
    bridge = generators.add_parser("bridge", help="执行固定版本的 FRB 生成器")
    bridge.add_argument("--check", action="store_true", help="隔离复核当前输入的生成物，不改写原工作区")
    build = commands.add_parser("build", help="编译各平台 FFI 或构建 Android/Windows 应用")
    builders = build.add_subparsers(dest="component", required=True)
    ffi = builders.add_parser("ffi", help="独立编译原生 FFI")
    ffi_platforms = ffi.add_subparsers(dest="platform", required=True)
    android_ffi = ffi_platforms.add_parser("android", help="编译 Android Rust 库")
    windows_ffi = ffi_platforms.add_parser("windows", help="编译并校验 Windows x64 DLL")
    ios_options(ffi_platforms.add_parser("ios", help="编译正式 iOS arm64 静态库，需要 macOS/Xcode"))
    android = builders.add_parser("android", help="构建 FFI、严格校验并打包 APK")
    windows = builders.add_parser("windows", help="构建 Windows DLL 与 Flutter 应用")
    for builder in (android_ffi, android):
        android_options(builder, build=True)
    for builder in (windows_ffi, windows):
        windows_options(builder, build=True)
    android.add_argument("--skip-rust", action="store_true", help="只跳过 Rust 编译，仍严格校验已有库")
    android.add_argument("--clean", action="store_true", help="先执行 flutter clean")
    android.add_argument("--split-per-abi", action="store_true", help="按 ABI 输出独立 APK")
    android.add_argument("--install", action="store_true", help="打包校验后安装并启动应用")
    android.add_argument("--device", help="明确指定 adb 设备编号")
    android.add_argument("--adb", type=Path, help="显式指定 adb 可执行文件")
    run = commands.add_parser("run", help="编译当前 DLL 后启动 Flutter 开发会话")
    runners = run.add_subparsers(dest="platform", required=True)
    windows_options(runners.add_parser("windows"), build=True)
    verify = commands.add_parser("verify", help="只读校验构建产物")
    verifiers = verify.add_subparsers(dest="component", required=True)
    verify_ffi = verifiers.add_parser("ffi", help="只读校验 FFI 原生库")
    verify_platforms = verify_ffi.add_subparsers(dest="platform", required=True)
    android_options(verify_platforms.add_parser("android"))
    windows_options(verify_platforms.add_parser("windows"))
    ios_options(verify_platforms.add_parser("ios"))
    verify_app = verifiers.add_parser("app", help="只读校验最终应用的原生符号")
    verify_app.add_argument("platform", choices=("ios",))
    ios_options(verify_app)
    verify_app.add_argument("--app", type=Path, required=True, help="已构建的 Runner.app 路径")
    verify_apk = verifiers.add_parser("apk", help="只读校验最终 APK")
    verify_apk.add_argument("platform", choices=("android",))
    android_options(verify_apk)
    verify_apk.add_argument("--apk", type=Path, required=True, help="待检查 APK 的路径")
    verify_apk.add_argument("--ndk", type=Path, help="APK strip 正规化使用的 NDK")
    verify_apk.add_argument("--signing-cert-sha256", help="同时校验APK签名及预期发行证书指纹")
    verify_icons = verifiers.add_parser("icons", help="只读检查 iOS 源资产、编译日志或最终图标声明")
    verify_icons.add_argument("platform", choices=("ios",))
    icon_inputs = verify_icons.add_mutually_exclusive_group(required=True)
    icon_inputs.add_argument("--assets", type=Path, help="Assets.xcassets 源目录")
    icon_inputs.add_argument("--build-log", type=Path, help="Flutter iOS 构建日志")
    icon_inputs.add_argument("--app", type=Path, help="完成 legacy 转换的 Runner.app")
    verify_ipa = verifiers.add_parser("ipa", help="只读检查 IPA 完整性、plist 与 Runner")
    verify_ipa.add_argument("platform", choices=("ios",))
    verify_ipa.add_argument("--ipa", type=Path, required=True)
    prepare = commands.add_parser("prepare", help="签名前执行现有 iOS 图标兼容处理")
    prepare.add_argument("component", choices=("icons",))
    prepare.add_argument("platform", choices=("ios",))
    prepare.add_argument("--assets", type=Path, required=True)
    prepare.add_argument("--app", type=Path, required=True)
    package = commands.add_parser("package", help="复制已构建的应用并打包，不编译或签名")
    package.add_argument("platform", choices=("ios",))
    package.add_argument("--app", type=Path, required=True)
    package.add_argument("--ipa", type=Path, required=True)
    export = commands.add_parser("export", help="导出 iOS plist 诊断文件，不改写源应用")
    export.add_argument("component", choices=("plist",))
    export.add_argument("platform", choices=("ios",))
    export.add_argument("--app", type=Path, required=True)
    export.add_argument("--output-dir", type=Path, required=True)
    collect = commands.add_parser("collect", help="校验并收集已构建的产物，不编译或发布 Release")
    collect.add_argument("component", choices=("apk",))
    collect.add_argument("platform", choices=("android",))
    android_options(collect)
    collect.add_argument("--output-dir", type=Path, required=True, help="仓库内专用收集目录，收集分 ABI APK")
    collect.add_argument("--ndk", type=Path, help="APK strip 正规化使用的 NDK")
    collect.add_argument("--signing-cert-sha256", help="收集前校验各APK的发行签名证书")
    test = commands.add_parser("test", help="运行工程工具测试")
    test.add_argument("component", choices=("tooling",))
    args = parser.parse_args(argv)
    try:
        if args.command == "fingerprint":
            from tooling.fingerprint import rust_fingerprint
            print(rust_fingerprint(ROOT / "rust"))
        elif args.command == "generate":
            if args.component == "dart":
                from tooling.bridge import generate_dart
                generate_dart(ROOT, check=args.check)
            else:
                from tooling.bridge import generate_bridge
                generate_bridge(ROOT, args.check)
            print("生成复核通过。" if getattr(args, "check", False) else "代码生成完成，请另行重编相应原生库。")
        elif args.command == "build":
            if args.component == "ffi":
                if args.platform == "windows":
                    from tooling.windows import build_windows_ffi
                    output = build_windows_ffi(ROOT, args.profile, args.cargo_target_dir, not args.no_quickjs, args.clean)
                    print(f"Windows FFI 构建与校验通过：{output}")
                elif args.platform == "ios":
                    from tooling.ios import build_ios_ffi
                    output = build_ios_ffi(ROOT, args.target, args.profile, args.cargo_target_dir)
                    print(f"iOS {args.target} 静态库构建与校验通过：{output}")
                else:
                    from tooling.android import build_android_ffi
                    output = build_android_ffi(ROOT, args.profile, args.abis, args.ndk, args.cargo_target_dir)
                    print(f"Android FFI 构建与校验通过：{', '.join(args.abis)}；Cargo 输出：{output}")
            elif args.component == "windows":
                from tooling.windows_app import build_windows_app
                output = build_windows_app(ROOT, args.profile, args.cargo_target_dir, not args.no_quickjs, args.clean)
                print(f"Windows 应用构建与 DLL 复制校验通过：{output}")
            else:
                from tooling.android_app import build_android_app
                apks = build_android_app(ROOT, args.profile, args.abis, args.ndk, args.cargo_target_dir,
                                         args.skip_rust, args.clean, args.split_per_abi,
                                         args.install, args.device, args.adb)
                for apk in apks:
                    print(f"Android APK 构建与包内原生库校验通过：{apk}")
        elif args.command == "run":
            from tooling.windows_app import build_windows_app
            build_windows_app(ROOT, args.profile, args.cargo_target_dir, not args.no_quickjs, args.clean, run=True)
        elif args.command == "collect":
            from tooling.android_app import collect_android_apks
            apks = collect_android_apks(ROOT, args.profile, args.abis, args.output_dir, args.ndk, args.cargo_target_dir,
                                       args.signing_cert_sha256)
            for apk in apks:
                print(f"已校验并收集 APK：{apk}")
        elif args.command == "prepare":
            from tooling.ios_bundle import prepare_bundle_icons
            prepare_bundle_icons(ROOT, args.assets, args.app)
        elif args.command == "package":
            from tooling.ios_bundle import package_ios_ipa
            output = package_ios_ipa(ROOT, args.app, args.ipa)
            print(f"IPA 打包与完整性校验通过：{output}")
        elif args.command == "export":
            from tooling.ios_bundle import export_ios_plist
            export_ios_plist(ROOT, args.app, args.output_dir)
            print(f"已导出 plist 诊断文件：{args.output_dir}")
        elif args.command == "verify":
            if args.component == "icons":
                if args.assets is not None:
                    from tooling.ios_bundle import verify_icon_assets
                    verify_icon_assets(args.assets)
                    print("六个备选图标的源资产引用文件完整。")
                elif args.build_log is not None:
                    from tooling.ios_bundle import verify_icon_build_log
                    verify_icon_build_log(args.build_log)
                    print("actool 无 unassigned children 警告。")
                else:
                    from tooling.ios_bundle import verify_bundle_icons
                    verify_bundle_icons(args.app)
                    print("最终 plist 与六个备选图标引用资源完整；运行时能力仍须真机验证。")
            elif args.component == "ipa":
                from tooling.ios_bundle import verify_ios_ipa
                verify_ios_ipa(args.ipa)
                print(f"IPA 完整性、plist 与 Runner 校验通过：{args.ipa}")
            elif args.component == "apk":
                from tooling.android_app import verify_android_apk
                verify_android_apk(ROOT, args.apk, args.profile, args.abis, args.ndk, args.cargo_target_dir,
                                   args.signing_cert_sha256)
                print(f"APK 包内原生库校验通过：{args.apk}")
            elif args.component == "app":
                from tooling.ios import verify_ios_app
                verify_ios_app(ROOT, args.target, args.profile, args.app, args.cargo_target_dir)
                print(f"iOS {args.target} 应用 PDE 符号校验通过：{args.app}")
            elif args.platform == "ios":
                from tooling.ios import verify_ios_ffi
                output = verify_ios_ffi(ROOT, args.target, args.profile, args.cargo_target_dir)
                print(f"iOS {args.target} 静态库只读校验通过：{output}")
            elif args.platform == "windows":
                from tooling.windows import verify_windows_ffi
                output = verify_windows_ffi(ROOT, args.profile, args.cargo_target_dir, not args.no_quickjs)
                print(f"Windows FFI 只读校验通过：{output}")
            else:
                from tooling.ffi_metadata import verify_android
                for result in verify_android(ROOT, args.profile, args.abis, args.cargo_target_dir):
                    source = "源库摘要已核对" if result.source_checked else "未核对 Cargo 源库"
                    print(f"{result.abi}：校验通过（{args.profile}，{source}）")
        else:
            tests = ROOT / "tests" / "tooling"
            if not tests.is_dir():
                raise ToolError("工程工具测试目录不存在。")
            suite = unittest.defaultTestLoader.discover(str(tests))
            if suite.countTestCases() == 0:
                raise ToolError("没有发现工程工具测试，不能报告通过。")
            return 0 if unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful() else 1
        return 0
    except CommandError as exc:
        report_error(exc)
        return exc.code
    except (ToolError, OSError) as exc:
        report_error(exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())
