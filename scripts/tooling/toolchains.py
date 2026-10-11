"""读取已安装工具与工程配置；不安装 SDK、不写本机环境配置。"""

from dataclasses import dataclass
from pathlib import Path
import re
import shlex
import shutil
import sys
import tomllib

from .common import ToolError, read_text
from .ffi_metadata import unique_match


def find_tool(name: str, env: dict) -> Path:
    found = shutil.which(name, path=env.get("PATH", ""))
    if not found:
        raise ToolError(f"PATH 中找不到 {name}，请先安装并配置该工具。")
    return Path(found).resolve()


def rust_environment(root: Path, env: dict) -> dict:
    config = root / "rust" / "rust-toolchain.toml"
    try:
        channel = tomllib.loads(read_text(config))["toolchain"]["channel"]
    except (tomllib.TOMLDecodeError, KeyError) as exc:
        raise ToolError(f"Rust 工具链配置无法解析：{config}") from exc
    if not isinstance(channel, str) or not channel:
        raise ToolError("rust-toolchain.toml 缺少明确的 channel。")
    return {**env, "RUSTUP_TOOLCHAIN": channel}


def dart_environment(env: dict) -> tuple[Path, dict]:
    dart = find_tool("dart", env)
    result = env.copy()
    if dart.suffix.lower() in (".bat", ".cmd"):
        # Windows PATH 中的 dart.bat 属于 Flutter，直接使用该 SDK 的 Dart 引擎。
        sdk = dart.parent.parent
        dart = sdk / "bin" / "cache" / "dart-sdk" / "bin" / "dart.exe"
        result["FLUTTER_ROOT"] = str(sdk)
    elif dart.parent.parent.name == "dart-sdk":
        sdk = dart.parents[4]
        if (sdk / "packages" / "flutter").is_dir():
            result["FLUTTER_ROOT"] = str(sdk)
    if not dart.is_file():
        raise ToolError(f"找不到 SDK 内的 Dart 可执行文件：{dart}")
    return dart, result


def flutter_command(env: dict) -> tuple[list[str], dict]:
    """按 PATH 选择 Flutter；Windows 使用同一 SDK 的原生 Dart 启动器。"""
    flutter = find_tool("flutter", env)
    if flutter.suffix.lower() not in (".bat", ".cmd"):
        return [str(flutter)], env.copy()
    sdk = flutter.parent.parent
    dart = sdk / "bin" / "cache" / "dart-sdk" / "bin" / "dart.exe"
    snapshot = sdk / "bin" / "cache" / "flutter_tools.snapshot"
    packages = sdk / "packages" / "flutter_tools" / ".dart_tool" / "package_config.json"
    if not all(path.is_file() for path in (dart, snapshot, packages)):
        raise ToolError("PATH 中的 Flutter SDK 尚未初始化；请先执行 flutter doctor 后重试。")
    # 与 flutter.bat 的最终 Dart 调用一致；不拼接批处理命令，也不修改 SDK。
    return [str(dart), f"--packages={packages}", str(snapshot)], {**env, "FLUTTER_ROOT": str(sdk)}


def property_value(path: Path, key: str) -> str:
    value = unique_match(rf"^{re.escape(key)}[ \t]*=[ \t]*([^\r\n]+)$", read_text(path), str(path) + ":" + key)
    return value.strip().replace("\\:", ":").replace("\\ ", " ").replace("\\\\", "\\")


@dataclass(frozen=True)
class AndroidNdk:
    root: Path
    version: str
    bin: Path
    sysroot: Path

    def tool(self, name: str) -> Path:
        path = self.bin / (name + (".exe" if sys.platform == "win32" else ""))
        if not path.is_file():
            raise ToolError(f"NDK 工具不存在：{path}")
        return path


def discover_ndk(root: Path, policy: dict, env: dict, explicit: Path | None = None) -> AndroidNdk:
    candidate = explicit
    if candidate is None:
        direct = env.get("ANDROID_NDK_HOME") or env.get("ANDROID_NDK_ROOT")
        if direct:
            candidate = Path(direct)
        else:
            sdk = env.get("ANDROID_SDK_ROOT") or env.get("ANDROID_HOME")
            if not sdk:
                local = root / "flutter_legado" / "android" / "local.properties"
                if local.is_file():
                    sdk = property_value(local, "sdk.dir")
            if sdk:
                candidate = Path(sdk) / "ndk" / policy["ndkVersion"]
    if candidate is None or not candidate.is_dir():
        raise ToolError(f"缺少 Android NDK {policy['ndkVersion']}；请安装后用 --ndk 或 SDK/NDK 环境变量指定。")
    candidate = candidate.resolve()
    version = property_value(candidate / "source.properties", "Pkg.Revision")
    if version != policy["ndkVersion"]:
        raise ToolError(f"NDK 版本不匹配：要求 {policy['ndkVersion']}，实际 {version}。")
    tags = {"win32": "windows-x86_64", "linux": "linux-x86_64", "darwin": "darwin-x86_64"}
    if sys.platform not in tags:
        raise ToolError(f"当前宿主不支持 Android NDK 构建：{sys.platform}")
    toolchain = candidate / "toolchains" / "llvm" / "prebuilt" / tags[sys.platform]
    ndk = AndroidNdk(candidate, version, toolchain / "bin", toolchain / "sysroot")
    for name in ("clang", "clang++", "llvm-ar", "llvm-strip"):
        ndk.tool(name)
    if not ndk.sysroot.is_dir():
        raise ToolError(f"NDK sysroot 不存在：{ndk.sysroot}")
    return ndk


def android_environment(env: dict, ndk: AndroidNdk, target: dict, policy: dict) -> dict:
    result = env.copy()
    # 编译参数由策略确定；只清理子进程中会覆盖它们的通用设置。
    for name in ("CC", "CXX", "AR", "CFLAGS", "CXXFLAGS", "CPPFLAGS", "LDFLAGS", "RUSTFLAGS", "BINDGEN_EXTRA_CLANG_ARGS"):
        result.pop(name, None)
    triple = target["targetTriple"]
    suffix = triple.replace("-", "_")
    clang_target = f"{target['clangTarget']}{policy['clangApiLevel']}"
    sysroot = ndk.sysroot.as_posix()
    flags = [f"--target={clang_target}", f"--sysroot={sysroot}"]
    include = ndk.sysroot / "usr" / "include" / target["sysrootTriple"]
    if not include.is_dir():
        raise ToolError(f"NDK 目标头文件目录不存在：{include}")
    result.update({
        "ANDROID_NDK_HOME": str(ndk.root),
        "ANDROID_NDK_ROOT": str(ndk.root),
        f"CC_{suffix}": str(ndk.tool("clang")),
        f"CXX_{suffix}": str(ndk.tool("clang++")),
        f"AR_{suffix}": str(ndk.tool("llvm-ar")),
        f"CFLAGS_{suffix}": shlex.join(flags),
        f"CXXFLAGS_{suffix}": shlex.join(flags),
        "CC_SHELL_ESCAPED_FLAGS": "1",
        f"CARGO_TARGET_{suffix.upper()}_LINKER": str(ndk.tool("clang")),
        "CARGO_ENCODED_RUSTFLAGS": "\x1f".join([
            "-C", f"link-arg=--target={clang_target}",
            "-C", f"link-arg=--sysroot={sysroot}",
            "-C", f"link-arg=-Wl,-z,max-page-size={policy['maxPageSize']}",
            "-C", f"link-arg=-Wl,-z,common-page-size={policy['maxPageSize']}",
        ]),
        f"BINDGEN_EXTRA_CLANG_ARGS_{triple}": shlex.join([*flags, f"-I{include.as_posix()}"]),
        f"BINDGEN_EXTRA_CLANG_ARGS_{suffix}": shlex.join([*flags, f"-I{include.as_posix()}"]),
    })
    # cc-rs 同时接受 target 中保留连字符和替换为下划线的变量；两种写法统一覆盖。
    for name in ("CC", "CXX", "AR", "CFLAGS", "CXXFLAGS"):
        result[f"{name}_{triple}"] = result[f"{name}_{suffix}"]
    return result
