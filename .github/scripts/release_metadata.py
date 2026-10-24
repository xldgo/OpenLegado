"""正式/Alpha发布编号及附件命名；不生成客户端更新清单。"""

import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile


ROOT = Path(__file__).resolve().parents[2]
ANDROID_ABIS = ("arm64-v8a", "armeabi-v7a", "x86_64")
BUILD_BASE = 10000  # 单一Release工作流递增；高于已有包的440，不因渠道或平台重置。


def release_plan(version, run_number, ref, channel="alpha", publish=False, event_name="push"):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("发布版本必须是X.Y.Z")
    if event_name == "push" and ref.startswith("refs/tags/"):
        if ref != f"refs/tags/v{version}":
            raise ValueError("正式标签必须为v<pubspec版本>；Alpha请使用手动发布")
        channel, publish = "stable", True
    if channel not in ("alpha", "stable"):
        raise ValueError("未知发布渠道")
    build = BUILD_BASE + int(run_number)
    return {
        "version": version,
        "build_number": str(build),
        "channel": channel,
        "tag": f"v{version}" if channel == "stable" else f"v{version}-alpha.{build}",
        "publish": str(publish).lower(),
    }


def artifact_name(version, build, suffix):
    return f"OpenLegado-{version}+{build}-{suffix}"


def stage(root, platform, version, build, destination):
    destination.mkdir(parents=True, exist_ok=True)
    if platform == "android":
        for abi in ANDROID_ABIS:
            source = root / "release-apk" / f"app-{abi}-release.apk"
            if not source.is_file() or not source.stat().st_size:
                raise ValueError(f"缺少已校验APK：{source}")
        for abi in ANDROID_ABIS:
            shutil.copyfile(
                root / "release-apk" / f"app-{abi}-release.apk",
                destination / artifact_name(version, build, f"android-{abi}.apk"),
            )
    else:
        bundle = root / "flutter_legado/build/windows/x64/runner/Release"
        if not (bundle / "flutter_legado.exe").is_file():
            raise ValueError("缺少Windows发行程序")
        archive = destination / artifact_name(version, build, "windows-x64.zip")
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as output:
            for path in sorted(bundle.rglob("*")):
                if path.is_file():
                    output.write(path, path.relative_to(bundle))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "stage", "notes"))
    parser.add_argument("--platform", choices=("android", "windows"))
    args = parser.parse_args()
    if args.command == "prepare":
        if os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch" and not any(
            os.environ.get(key) == "true" for key in ("BUILD_ANDROID", "BUILD_WINDOWS", "BUILD_IOS")
        ):
            parser.error("至少选择一个构建平台")
        pubspec = (ROOT / "flutter_legado/pubspec.yaml").read_text(encoding="utf-8")
        version = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$", pubspec, re.M)
        if version is None:
            parser.error("pubspec缺少明确的版本和构建号")
        plan = release_plan(
            version[1], os.environ["GITHUB_RUN_NUMBER"], os.environ["GITHUB_REF"],
            os.environ.get("RELEASE_CHANNEL", "alpha"), os.environ.get("PUBLISH_RELEASE") == "true",
            os.environ["GITHUB_EVENT_NAME"],
        )
        if plan["publish"] == "true":
            # 手动正式发布也可能遇到已存在的标签，不能让标签指向另一次源码。
            tag_ref = f"refs/tags/{plan['tag']}"
            remote = subprocess.check_output(
                ["git", "ls-remote", "origin", tag_ref, f"{tag_ref}^{{}}"],
                cwd=ROOT, text=True, timeout=30,
            )
            refs = {ref: sha for sha, ref in (line.split() for line in remote.splitlines())}
            target = refs.get(f"{tag_ref}^{{}}", refs.get(tag_ref))
            if target is not None and target != os.environ["GITHUB_SHA"]:
                raise ValueError("发布标签指向其他提交，拒绝关联错误源码")
        plan["built_at"] = datetime.now(timezone.utc).isoformat()
        with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as output:
            for key, value in plan.items():
                output.write(f"{key}={value}\n")
        print(f"本次构建：{plan['tag']} / {plan['build_number']}；发布：{plan['publish']}")
    elif args.command == "stage":
        if args.platform is None:
            parser.error("stage必须指定--platform")
        stage(ROOT, args.platform, os.environ["RELEASE_VERSION"],
              os.environ["RELEASE_BUILD"], ROOT / "release-dist")
    else:
        version = os.environ["RELEASE_VERSION"]
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        section = re.search(rf"^## \[{re.escape(version)}\].*?\n(.*?)(?=^## |\Z)",
                            changelog, re.M | re.S)
        notes = section[1].strip() if section else "暂无更新说明"
        if os.environ.get("BUILD_IOS") == "true":
            notes = "iOS附件为未签名IPA，需通过侧载工具自行签名安装。\n\n" + notes
        body = (f"# OpenLegado {version}\n\n"
                f"- 渠道：{os.environ['RELEASE_CHANNEL']}\n"
                f"- 构建号：{os.environ['RELEASE_BUILD']}\n"
                f"- 源码：{os.environ['GITHUB_SHA']}\n"
                f"- 构建时间：{os.environ['RELEASE_BUILT_AT']}\n\n{notes}\n")
        (ROOT / "release-notes.md").write_text(body, encoding="utf-8")


if __name__ == "__main__":
    main()
