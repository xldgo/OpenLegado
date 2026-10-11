"""工程工具共用的错误与只读文件操作。"""

import hashlib
import json
import os
from pathlib import Path
import subprocess


class ToolError(Exception):
    """可直接向用户报告的校验或配置错误。"""


class CommandError(ToolError):
    def __init__(self, program, code):
        super().__init__(f"{program} 执行失败，退出码 {code}。")
        self.code = code if 0 < code < 256 else 1


def output_directory(root: Path, explicit: Path | None = None) -> Path:
    """解释 Cargo 输出目录；仓库 Rust 树内只允许被指纹排除的 target 目录。"""
    output = explicit or Path(os.environ.get("CARGO_TARGET_DIR", root / "rust" / "target"))
    if not output.is_absolute():
        output = (Path.cwd() if explicit is not None else root / "rust") / output
    output = output.resolve()
    rust = (root / "rust").resolve()
    if output.is_relative_to(rust) and "target" not in output.relative_to(rust).parts:
        raise ToolError("Rust 树内的 Cargo 输出目录必须位于 target 下，避免污染源码指纹。")
    return output


def run_command(args, cwd: Path, env: dict, capture=False):
    """使用参数数组调用原生程序；失败保留原始退出码，stderr 直接输出。"""
    args = [str(value) for value in args]
    if Path(args[0]).suffix.lower() in (".bat", ".cmd"):
        raise ToolError("工程工具直接调用原生可执行文件，不拼接 Windows 批处理命令。")
    print(f"执行：{Path(args[0]).name}（目录：{cwd}）", flush=True)
    result = subprocess.run(args, cwd=cwd, env=env, shell=False,
                            stdout=subprocess.PIPE if capture else None,
                            text=True, encoding="utf-8", errors="replace")
    if result.returncode:
        if capture and result.stdout:
            print(result.stdout, end="", flush=True)
        raise CommandError(Path(args[0]).name, result.returncode)
    return result.stdout if capture else ""


def cargo_artifact(output: str, expected: Path) -> Path:
    """要求成功的 Cargo 调用明确报告本次库产物，拒绝只查旧文件是否存在。"""
    found = False
    for line in output.splitlines():
        try:
            message = json.loads(line)
        except ValueError as exc:
            raise ToolError("Cargo JSON 输出无法解析，不能确认本次编译产物。") from exc
        if message.get("reason") == "compiler-message":
            rendered = message.get("message", {}).get("rendered")
            if rendered:
                print(rendered, end="", flush=True)
        if message.get("reason") == "compiler-artifact" and message.get("target", {}).get("name") == "legado_ffi":
            found |= any(Path(filename).resolve() == expected.resolve() for filename in message.get("filenames", []))
    if not found or not expected.is_file() or not expected.stat().st_size:
        raise ToolError(f"Cargo 未确认本次 legado-ffi 库产物：{expected}")
    return expected


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        raise ToolError(f"无法读取 {path}：{exc}") from exc


def read_json(path: Path) -> dict:
    def object_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ToolError(f"{path}：JSON 字段 {key} 重复。")
            result[key] = value
        return result

    def constant(value):
        raise ToolError(f"{path}：JSON 不允许 {value}。")

    try:
        result = json.loads(read_text(path), object_pairs_hook=object_pairs, parse_constant=constant)
    except ValueError as exc:
        raise ToolError(f"{path}：JSON 损坏。") from exc
    if type(result) is not dict:
        raise ToolError(f"{path}：JSON 根节点必须是对象。")
    return result
