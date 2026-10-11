"""Android NDK 查找与交叉编译环境；与其他平台工具链隔离。"""

from dataclasses import dataclass
from pathlib import Path
import shlex
import sys

from .common import ToolError
from .toolchains import property_value


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
