#!/usr/bin/env python3
"""为不同 agent 创建指向仓库唯一 skills 来源的本地目录链接。"""

import os
from pathlib import Path
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / ".agents" / "skills"


def powershell_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def setup():
    if not SOURCE.is_dir() or not any(SOURCE.glob("*/SKILL.md")):
        raise RuntimeError(f"找不到 skills 来源：{SOURCE}")

    destinations = [ROOT / agent / "skills" for agent in (".claude", ".qoder")]
    # 先检查全部目标，已有独立目录或错误链接由维护者处理，不自动覆盖。
    for destination in destinations:
        if os.path.lexists(destination) and destination.resolve() != SOURCE.resolve():
            raise RuntimeError(f"目标已有独立目录或其他链接，请先核对：{destination}")

    for destination in destinations:
        if os.path.lexists(destination):
            print(f"已连接：{destination.relative_to(ROOT)} → .agents/skills")
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        if os.name == "nt":
            # 目录联接适用于本地 Windows 仓库，不依赖符号链接的管理员权限。
            command = (
                "$ErrorActionPreference = 'Stop'; "
                "New-Item -ItemType Junction "
                f"-Path {powershell_quote(destination)} "
                f"-Target {powershell_quote(SOURCE)} | Out-Null"
            )
            subprocess.run(
                ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command],
                check=True,
            )
        else:
            destination.symlink_to(
                os.path.relpath(SOURCE, destination.parent), target_is_directory=True
            )
        if destination.resolve() != SOURCE.resolve():
            raise RuntimeError(f"链接验证失败：{destination}")
        print(f"已连接：{destination.relative_to(ROOT)} → .agents/skills")


if __name__ == "__main__":
    try:
        setup()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"错误：{error}", file=sys.stderr)
        sys.exit(1)
