"""冻结现有 Android CI 构建矩阵；后续编译入口也使用这份配置。"""

import argparse
import hashlib
import json
from pathlib import Path
import re

from .common import ToolError, read_json, sha256_file
from .fingerprint import tree_fingerprint


INPUTS_ALGORITHM = "android-ffi-inputs-sha256-v1"


def load_policy(root: Path) -> dict:
    policy = read_json(root / "scripts" / "tooling" / "android-policy.json")
    if type(policy.get("schemaVersion")) is not int or policy["schemaVersion"] != 1:
        raise ToolError("Android 构建策略版本不受支持。")
    if not isinstance(policy.get("ndkVersion"), str) or not policy["ndkVersion"]:
        raise ToolError("Android 构建策略缺少 NDK 版本。")
    for name in ("clangApiLevel", "maxPageSize"):
        if type(policy.get(name)) is not int or policy[name] <= 0:
            raise ToolError(f"Android 构建策略的 {name} 必须是正整数。")
    targets = policy.get("targets")
    if type(targets) is not dict or not targets:
        raise ToolError("Android 构建策略缺少 targets。")
    for abi, target in targets.items():
        if type(target) is not dict or not isinstance(target.get("targetTriple"), str):
            raise ToolError(f"{abi}：构建策略缺少 targetTriple。")
        if type(target.get("flutterPlatform")) is not str or not target["flutterPlatform"].startswith("android-"):
            raise ToolError(f"{abi}：构建策略缺少 Flutter 平台映射。")
        for name in ("clangTarget", "sysrootTriple"):
            if type(target.get(name)) is not str or not re.fullmatch(r"[a-z0-9_-]+", target[name]):
                raise ToolError(f"{abi}：构建策略的 {name} 不合法。")
        if type(target.get("elfClass")) is not int or target["elfClass"] not in (1, 2):
            raise ToolError(f"{abi}：elfClass 必须是 1 或 2。")
        if type(target.get("elfMachine")) is not int or target["elfMachine"] <= 0:
            raise ToolError(f"{abi}：elfMachine 必须是正整数。")
        features = target.get("features")
        if type(features) is not dict or not features or set(features) - {"debug", "release"}:
            raise ToolError(f"{abi}：构建策略的 profile 不合法。")
        for values in features.values():
            if type(values) is not list or any(type(value) is not str for value in values):
                raise ToolError(f"{abi}：features 必须是字符串列表。")
            if values != sorted(set(values)):
                raise ToolError(f"{abi}：features 必须去重并排序。")
    platforms = [target["flutterPlatform"] for target in targets.values()]
    if len(platforms) != len(set(platforms)):
        raise ToolError("Android 策略的 Flutter 平台映射不能重复。")
    return policy


def parse_abis(value: str) -> tuple[str, ...]:
    abis = tuple(part.strip() for part in value.split(","))
    if not all(abis) or len(abis) != len(set(abis)):
        raise argparse.ArgumentTypeError("--abis 不能包含空条目或重复 ABI。")
    return abis


def select_target(policy: dict, abi: str, profile: str) -> dict:
    if profile not in ("debug", "release"):
        raise ToolError(f"不支持构建模式：{profile}")
    if abi not in policy["targets"]:
        raise ToolError(f"未知 Android ABI：{abi}")
    target = policy["targets"][abi]
    if profile not in target["features"]:
        raise ToolError(f"{abi}：现有构建矩阵不支持 {profile}，不能隐式改变 QuickJS 配置。")
    return target


def build_inputs_sha256(root: Path, policy: dict, abi: str, profile: str,
                        rust_hash: str, content_hash: int, version: str) -> str:
    target = select_target(policy, abi, profile)
    inputs = {
        "algorithm": INPUTS_ALGORITHM,
        "rustFingerprint": rust_hash,
        "contentHash": content_hash,
        "frbCodegenVersion": version,
        "abi": abi,
        "targetTriple": target["targetTriple"],
        "profile": profile,
        "features": target["features"][profile],
        "ndkVersion": policy["ndkVersion"],
        "clangApiLevel": policy["clangApiLevel"],
        "maxPageSize": policy["maxPageSize"],
        "entrypointSha256": sha256_file(root / "scripts" / "dev.py"),
        "toolingFingerprint": tree_fingerprint(
            root / "scripts" / "tooling", excluded_dirs=("__pycache__",),
            excluded_suffixes=(".pyc", ".pyo"),
        ),
    }
    payload = json.dumps(inputs, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()
