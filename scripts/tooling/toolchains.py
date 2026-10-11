"""读取已安装工具与工程配置；不安装 SDK、不写本机环境配置。"""

from pathlib import Path
import re
import shutil
import sys
import tomllib

from .common import ToolError, read_text
from .contracts import unique_match


def find_tool(name: str, env: dict) -> Path:
    found = shutil.which(name, path=env.get("PATH", ""))
    if not found:
        raise ToolError(f"PATH 中找不到 {name}，请先安装并配置该工具。")
    # Rustup 根据调用入口名称分派 cargo/rustc；解析符号链接会误调用 rustup 本身。
    return Path(found).absolute()


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
