"""按 Git 差异选择 CI 任务，并检查条件跳过后的汇总结果。"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from tooling.input_scopes import RUST_DRIVERS, tooling_platforms

TARGETS = ("flutter", "rust", "android_ffi", "windows_ffi", "ios_build", "tooling")
PLATFORM_TARGETS = {"android": "android_ffi", "windows": "windows_ffi", "ios": "ios_build", "rust": "rust"}


def classify_paths(paths):
    """集中维护任务范围；新输入默认进入所属模块的检查。"""
    selected = dict.fromkeys(TARGETS, False)

    def select(*targets):
        for target in targets:
            selected[target] = True

    for path in paths:
        platforms = tooling_platforms(path)
        if platforms is not None:
            select("tooling", *(PLATFORM_TARGETS[platform] for platform in platforms))
            continue
        if path in RUST_DRIVERS:
            select("tooling", *(PLATFORM_TARGETS[platform] for platform in RUST_DRIVERS[path]))
            continue
        if path.startswith("rust/scripts/"):
            # 未登记的 Rust 脚本仍在共享源码指纹中，不能仅按名称缩小检查范围。
            select("tooling", "rust", "android_ffi", "windows_ffi", "ios_build")
            continue
        if path.startswith(("tests/tooling/", ".github/actions/", ".github/scripts/", ".github/workflows/")):
            select("tooling")
        # assets 中的 Markdown 属于打包内容，不能按文档忽略。
        if path.startswith("docs/") or (
            path.endswith((".md", ".rst")) and "assets" not in path.split("/")
        ):
            continue
        if path.startswith("third_party/") or path == ".gitmodules":
            select(*TARGETS)
        elif path.startswith("rust/"):
            select("rust")
            # crate 的集成测试不进入正式原生库。
            parts = path.split("/")
            integration_test = len(parts) > 3 and parts[2] == "tests"
            if not integration_test:
                select("android_ffi", "windows_ffi", "ios_build")
            if path.startswith("rust/legado-layout/") or (path.startswith("rust/legado-ffi/") and not integration_test):
                select("flutter")
        elif path.startswith("flutter_legado/"):
            relative = path.removeprefix("flutter_legado/")
            if relative.startswith("android/"):
                select("android_ffi")
            elif relative.startswith("windows/"):
                select("windows_ffi")
            elif relative.startswith("ios/"):
                select("ios_build")
            elif relative.startswith("scripts/"):
                if not relative.startswith("scripts/archive/"):
                    select("flutter", "android_ffi", "windows_ffi", "ios_build")
            else:
                select("flutter")
                if relative in ("pubspec.yaml", "pubspec.lock", ".metadata", "flutter_rust_bridge.yaml"):
                    select("tooling", "android_ffi", "windows_ffi", "ios_build")
                elif relative.startswith(("lib/", "assets/")):
                    select("ios_build")
                if relative.startswith((
                    "lib/src/bridge/", "lib/src/services/rust_api",
                    "lib/src/services/book_api.", "lib/src/services/platform_bridge_service.",
                    "lib/src/models/", "lib/main.dart", "lib/src/app.dart",
                    "integration_test/ffi_smoke_test.",
                )):
                    select("android_ffi", "windows_ffi")
        elif path == "scripts/emulator_smoke_test.ps1":
            select("tooling", "android_ffi")
        elif path in (".github/workflows/flutter-ci.yml", ".github/scripts/flutter_test_report.py"):
            select("flutter")
        elif path == ".github/workflows/rust-ci.yml":
            select("rust")
        elif path == ".github/workflows/integration-smoke.yml":
            select("android_ffi", "windows_ffi")
        elif path == ".github/workflows/release.yml":
            select("android_ffi")
        elif path == ".github/workflows/ios-build.yml":
            select("ios_build")
    return selected


def classify_generation_paths(paths):
    """生成检查只跟随契约/模型/生成配置输入，不随普通页面重跑。"""
    selected = {"dart_generate": False, "bridge_generate": False}
    for path in paths:
        shared = path in ("flutter_legado/pubspec.yaml", "flutter_legado/pubspec.lock",
                          "scripts/tooling/bridge.py", "scripts/dev.py",
                          ".github/workflows/flutter-ci.yml") or path.startswith("third_party/")
        if shared or path in ("flutter_legado/build.yaml",) or (
            path.startswith("flutter_legado/lib/") and
            (path.startswith(("flutter_legado/lib/src/models/", "flutter_legado/lib/src/domain/models/"))
             or path.endswith(("_state.dart", ".freezed.dart", ".g.dart")))):
            selected["dart_generate"] = True
        if shared or path in ("flutter_legado/flutter_rust_bridge.yaml", "rust/Cargo.toml", "rust/Cargo.lock") or (
            path.startswith("rust/legado-ffi/") and path.endswith((".rs", ".toml")) and not path.startswith("rust/legado-ffi/tests/")) or path.startswith("flutter_legado/lib/src/bridge/"):
            selected["bridge_generate"] = True
    return selected


def test_needs_native(root, path, base=None):
    """测试分组沿用native标签；旧版本也参与，删除标签不能漏跑原生组。"""
    if path.startswith(("flutter_legado/test/ffi/", "flutter_legado/test/helpers/",
                        "flutter_legado/test/fixtures/", "flutter_legado/test/mocks/")) or not path.endswith("_test.dart"):
        return True
    texts = []
    current = root / path
    if current.is_file():
        texts.append(current.read_text(encoding="utf-8-sig"))
    if base is not None:
        # ls-tree探测旧路径存在性；不存在表示新增，其他Git错误仍须失败。
        names = git(root, "ls-tree", "--name-only", base, "--", path).splitlines()
        if names:
            texts.append(git(root, "show", f"{base}:{path}"))
    if not texts:
        return True
    # 此处读取的是测试分组元数据，不推断其业务依赖。普通组仍使用不存在的FFI库路径。
    return any(re.search(r"\bnative\b", text) and re.search(
        r"\bTags\s*\(|\btags\s*:", text,
    ) for text in texts)


def classify_native_test_paths(paths, root=None, base=None):
    """原生回归跟随边界、原生标签及共享夹具输入。"""
    root = ROOT if root is None else root
    for path in paths:
        if path.startswith("docs/") or (
            path.endswith((".md", ".rst")) and "assets" not in path.split("/")
        ):
            continue
        if path.startswith("third_party/") or path in (
            ".gitmodules", ".github/workflows/flutter-ci.yml",
            ".github/actions/setup-flutter-rust/action.yml",
            ".github/actions/ci-changes/action.yml", ".github/scripts/ci_changes.py",
            ".github/scripts/flutter_test_report.py",
        ):
            return {"native_tests": True}
        if path.startswith("rust/"):
            parts = path.split("/")
            integration_test = len(parts) > 3 and parts[2] == "tests"
            if not integration_test or path.startswith((
                "rust/legado-ffi/tests/fixtures/", "rust/legado-layout/tests/fixtures/",
            )):
                return {"native_tests": True}
        if not path.startswith("flutter_legado/"):
            continue
        relative = path.removeprefix("flutter_legado/")
        if relative in ("pubspec.yaml", "pubspec.lock", ".metadata", "flutter_rust_bridge.yaml", "dart_test.yaml"):
            return {"native_tests": True}
        if relative.startswith("test/"):
            if test_needs_native(root, path, base):
                return {"native_tests": True}
            continue
        if relative.startswith("lib/"):
            native_features = (
                "lib/src/features/reader/", "lib/src/features/search/",
                "lib/src/features/read_aloud/", "lib/src/features/audio/",
            )
            if relative.startswith("lib/src/features/") and not relative.startswith(native_features):
                continue
            if relative.startswith("lib/src/widgets/") and not relative.startswith((
                "lib/src/widgets/reader/", "lib/src/widgets/paragraph_layout_engine.dart",
            )):
                continue
            # 其它共享层或新目录默认进入原生组，避免只维护已知依赖白名单。
            return {"native_tests": True}
    return {"native_tests": False}


def git(root, *args):
    result = subprocess.run(
        ["git", *args], cwd=root, check=True, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.decode("utf-8")


def require_sha(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("事件缺少有效的 Git SHA，不能跳过检查")
    return value


def ensure_commit(root, sha):
    """浅检出中按 SHA 补取基线，不依赖分支名称或整仓历史。"""
    require_sha(sha)
    try:
        git(root, "cat-file", "-e", f"{sha}^{{commit}}")
    except subprocess.CalledProcessError:
        git(root, "fetch", "--no-tags", "--depth=1", "origin", sha)


def change_range(root, event_name, event, head):
    head = require_sha(head)
    if event_name == "push":
        if event.get("deleted"):
            return [], None
        base = require_sha(event.get("before"))
        if base == "0" * 40:
            return git(root, "ls-tree", "-r", "--name-only", "-z", head).split("\0")[:-1], None
    elif event_name == "pull_request":
        # checkout 的 PR 合并提交相对事件 base，反映本次实际测试的合并结果。
        base = require_sha(event["pull_request"]["base"]["sha"])
    else:
        raise ValueError(f"不支持的自动事件：{event_name}")
    ensure_commit(root, base)
    # 禁用重命名合并，删除旧路径与新增路径均参与任务选择。
    return git(root, "diff", "--no-renames", "--name-only", "-z", base, head).split("\0")[:-1], base


def changed_paths(root, event_name, event, head):
    return change_range(root, event_name, event, head)[0]


def flutter_manual_plan(root, scope, head, base_sha=""):
    """仅Flutter Workflow使用；其它工作流保留既有platform语义。"""
    if scope not in ("auto", "fast", "native", "all"):
        raise ValueError(f"未知Flutter手动范围：{scope}")
    if scope == "auto":
        head = require_sha(head)
        if base_sha:
            base = require_sha(base_sha)
            if base == "0" * 40:
                raise ValueError("手动比较基线必须为实际提交；完整检查请选择all")
        else:
            # changes作业检出两层历史；根提交无法比较时应显式选择all。
            base = git(root, "rev-parse", "--verify", f"{head}^1").strip()
        if base == head:
            raise ValueError("比较基线不能等于当前提交；完整检查请选择all")
        print(f"Flutter按改动检查：{base} -> {head}")
        paths, base = change_range(root, "push", {"before": base}, head)
        return path_plan(root, paths, base)
    selected = dict.fromkeys(TARGETS, False)
    selected["flutter"] = scope in ("fast", "all")
    selected.update(dict.fromkeys(("dart_generate", "bridge_generate"), scope == "all"))
    selected["native_tests"] = scope in ("native", "all")
    selected["flutter_checks"] = selected["flutter"]
    return selected


def path_plan(root, paths, base=None):
    selected = classify_paths(paths)
    selected.update(classify_generation_paths(paths))
    selected.update(classify_native_test_paths(paths, root, base))
    selected["flutter_checks"] = selected["flutter"] or selected["dart_generate"] or selected["bridge_generate"]
    return selected


def manual_scope(event):
    """无参数workflow_dispatch的inputs可能是null，统一视为全量手动检查。"""
    inputs = event.get("inputs")
    if inputs is None:
        return "all"
    if not isinstance(inputs, dict):
        raise ValueError("手动触发inputs必须为对象或null")
    platform = inputs.get("platform", "all")
    if platform not in ("all", "android", "windows"):
        raise ValueError(f"未知手动验证范围：{platform}")
    return platform


def plan(root, event_name, event, head):
    if event_name == "workflow_dispatch":
        platform = manual_scope(event)
        if platform == "all":
            return dict.fromkeys(TARGETS, True)
        if platform in ("android", "windows"):
            selected = dict.fromkeys(TARGETS, False)
            selected[f"{platform}_ffi"] = True
            return selected
        raise ValueError(f"未知手动验证范围：{platform}")
    return classify_paths(changed_paths(root, event_name, event, head))


def check_results(needs, jobs):
    """只允许未选中任务跳过；判定失败、必要任务失败或取消均不能通过。"""
    changes = needs.get("changes", {})
    if changes.get("result") != "success":
        raise ValueError("改动判定未成功，不能通过汇总检查")
    outputs = changes.get("outputs", {})
    for job, target in jobs.items():
        flag = outputs.get(target)
        if flag not in ("true", "false"):
            raise ValueError(f"任务 {job} 缺少有效的范围判定：{target}")
        expected = "success" if flag == "true" else "skipped"
        actual = needs.get(job, {}).get("result")
        if actual != expected:
            raise ValueError(f"任务 {job} 应为 {expected}，实际为 {actual}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("changes", help="读取 Actions 事件并输出任务范围")
    check = subparsers.add_parser("check", help="核对汇总检查的依赖结果")
    check.add_argument("jobs", nargs="+", help="任务名=范围名")
    args = parser.parse_args()
    try:
        if args.command == "changes":
            event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
            flutter_scope = os.environ.get("CI_FLUTTER_SCOPE", "")
            if flutter_scope:
                if os.environ["GITHUB_EVENT_NAME"] != "workflow_dispatch":
                    raise ValueError("Flutter手动范围只能用于workflow_dispatch")
                selected = flutter_manual_plan(ROOT, flutter_scope, os.environ["GITHUB_SHA"],
                                               os.environ.get("CI_FLUTTER_BASE_SHA", ""))
            elif os.environ["GITHUB_EVENT_NAME"] == "workflow_dispatch":
                selected = plan(ROOT, "workflow_dispatch", event, os.environ["GITHUB_SHA"])
                all_checks = manual_scope(event) == "all"
                generation = dict.fromkeys(("dart_generate", "bridge_generate"), all_checks)
                native = {"native_tests": all_checks}
                selected.update(generation)
                selected.update(native)
                selected["flutter_checks"] = selected["flutter"] or any(generation.values())
            else:
                paths, base = change_range(ROOT, os.environ["GITHUB_EVENT_NAME"], event, os.environ["GITHUB_SHA"])
                selected = path_plan(ROOT, paths, base)
            payload = "".join(f"{target}={str(value).lower()}\n" for target, value in selected.items())
            with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8", newline="\n") as output:
                output.write(payload)
            print(payload, end="")
        else:
            jobs = dict(item.split("=", 1) for item in args.jobs)
            check_results(json.loads(os.environ["CI_NEEDS"]), jobs)
            print("所有必要任务成功，无关任务按判定跳过")
        return 0
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f"CI 编排失败：{error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr.decode("utf-8", errors="replace"), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
