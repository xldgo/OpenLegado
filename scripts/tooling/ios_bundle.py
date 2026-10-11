"""iOS 图标兼容处理、plist 诊断和 IPA 编排；不负责签名。"""

import json
import os
from pathlib import Path
import plistlib
import shutil
import stat
import sys
import tempfile
import zipfile
import zlib
from xml.parsers.expat import ExpatError

from .common import ToolError, read_json, read_text, run_command
from .toolchains import find_tool


ICON_NAMES = tuple(f"launcher{index}" for index in range(1, 7))
ICON_SECTIONS = ("CFBundleIcons", "CFBundleIcons~ipad")
ICON_SUFFIXES = (".png", "@2x.png", "@3x.png", "~ipad.png", "@2x~ipad.png", "@3x~ipad.png")
LEGACY_SIZES = (("120", "60x60@2x"), ("76", "76x76@1x"),
                ("152", "76x76@2x"), ("180", "60x60@3x"))


def plist_data(content: bytes, label: str) -> dict:
    try:
        data = plistlib.loads(content)
    except (ValueError, TypeError, OverflowError, ExpatError, plistlib.InvalidFileException) as exc:
        raise ToolError(f"{label}：plist 无法解析。") from exc
    if not isinstance(data, dict):
        raise ToolError(f"{label}：plist 根节点必须是字典。")
    return data


def read_plist(path: Path) -> dict:
    return plist_data(path.read_bytes(), str(path))


def build_path(root: Path, path: Path) -> Path:
    """只在本仓库 Flutter 构建目录写入，不改动源工程或外部应用。"""
    resolved = path.resolve()
    build = root.resolve() / "flutter_legado" / "build"
    if build.resolve() != build or resolved == build or not resolved.is_relative_to(build):
        raise ToolError(f"输出必须位于本仓库 flutter_legado/build 内：{path}")
    if path.is_symlink():
        raise ToolError(f"输出不能是符号链接：{path}")
    return resolved


def icon_file(directory: Path, filename: str) -> Path:
    if not isinstance(filename, str) or not filename or filename in (".", "..") or any(c in filename for c in ("/", "\\", "\x00", ":")):
        raise ToolError(f"图标文件引用必须是文件名：{filename!r}")
    path = directory / filename
    if not path.resolve().is_relative_to(directory.resolve()):
        raise ToolError(f"图标文件越出所属目录：{path}")
    return path


def verify_icon_assets(assets: Path):
    for name in ICON_NAMES:
        directory = assets / f"{name}.appiconset"
        images = read_json(directory / "Contents.json").get("images")
        if not isinstance(images, list) or not images:
            raise ToolError(f"{directory}：缺少有效 images 图标槽位。")
        for image in images:
            if not isinstance(image, dict):
                raise ToolError(f"{directory}：图标槽位必须是对象。")
            # 无 filename 的未配置槽位继续由 actool 日志门禁判断。
            if "filename" in image:
                path = icon_file(directory, image["filename"])
                if not path.is_file():
                    raise ToolError(f"图标资产引用文件不存在：{path}")


def verify_icon_build_log(log: Path):
    matches = [f"{index}: {line}" for index, line in enumerate(read_text(log).splitlines(), 1)
               if "unassigned children" in line]
    if matches:
        raise ToolError("actool 报告图标资产存在未分配槽位图像：\n" + "\n".join(matches[:10]))


def legacy_plist(data: dict) -> int:
    """保持原转换条件：仅替换带 CFBundleIconName 的备选图标。"""
    converted = 0
    for section in ICON_SECTIONS:
        icons = data.get(section)
        alternates = icons.get("CFBundleAlternateIcons") if isinstance(icons, dict) else None
        if not isinstance(alternates, dict):
            continue
        for name, entry in alternates.items():
            if isinstance(entry, dict) and "CFBundleIconName" in entry:
                del entry["CFBundleIconName"]
                size = "76x76" if section == "CFBundleIcons~ipad" else "60x60"
                entry["CFBundleIconFiles"] = [f"{name}{size}"]
                converted += 1
    if converted < 6:
        raise ToolError(f"legacy 转换至少需要 6 个带资产名的备选图标，实际为 {converted}。")
    return converted


def verify_bundle_icons(app: Path):
    data = read_plist(app / "Info.plist")
    for section in ICON_SECTIONS:
        icons = data.get(section)
        if section == "CFBundleIcons~ipad" and icons is None:
            continue
        if not isinstance(icons, dict):
            raise ToolError(f"缺少图标声明：{section}")
        alternates = icons.get("CFBundleAlternateIcons")
        if not isinstance(alternates, dict) or set(alternates) != set(ICON_NAMES):
            raise ToolError(f"六个备选图标声明不完整：{section}")
        for name, entry in alternates.items():
            if not isinstance(entry, dict) or "CFBundleIconName" in entry:
                raise ToolError(f"legacy 转换未完成：{section}/{name}")
            filenames = entry.get("CFBundleIconFiles")
            if not isinstance(filenames, list) or not filenames:
                raise ToolError(f"缺少图标文件引用：{section}/{name}")
            for filename in filenames:
                icon_file(app, filename)
                base = filename.removesuffix(".png")
                if not any(icon_file(app, base + suffix).is_file() for suffix in ICON_SUFFIXES):
                    raise ToolError(f"图标资源缺失：{section}/{name}/{filename}")


def prepare_bundle_icons(root: Path, assets: Path, app: Path):
    app = build_path(root, app)
    if not app.is_dir():
        raise ToolError(f"待处理的应用目录不存在：{app}")
    plist = app / "Info.plist"
    if plist.is_symlink():
        raise ToolError("Info.plist 不能是符号链接，拒绝改写外部文件。")
    data = read_plist(plist)
    copies = [(assets / f"{name}.appiconset" / f"{name}_{size}.png", icon_file(app, f"{name}{suffix}.png"))
              for name in ICON_NAMES for size, suffix in LEGACY_SIZES]
    copies.append((assets / "AppIcon.appiconset" / "Icon-App-60x60@3x.png", icon_file(app, "AppIcon60x60@3x.png")))
    for source, destination in copies:
        if not source.is_file():
            raise ToolError(f"legacy 图标散文件缺失：{source}")
        if destination.is_symlink():
            raise ToolError(f"图标输出不能是符号链接：{destination}")
    converted = legacy_plist(data)
    # 先确认全部源文件和转换条件；不通过时不复制、不覆盖 plist。
    for source, destination in copies:
        shutil.copyfile(source, destination)
    plist.write_bytes(plistlib.dumps(data))
    verify_bundle_icons(app)
    print(f"已复制 24 个备选图标散文件与主图标，转换 {converted} 个 legacy 声明。")
    if converted != 12:
        print(f"::warning::预期转换 12 个声明（六个图标、两个设备区段），实际为 {converted}。")


def verify_ios_ipa(ipa: Path):
    try:
        with zipfile.ZipFile(ipa) as archive:
            entries = archive.infolist()
            names = [entry.filename for entry in entries]
            if len(names) != len(set(names)):
                raise ToolError(f"{ipa}：IPA 含重复 ZIP 条目。")
            corrupt = archive.testzip()
            if corrupt is not None:
                raise ToolError(f"{ipa}：IPA CRC 校验失败：{corrupt}")
            plist_data(archive.read("Payload/Runner.app/Info.plist"), str(ipa) + "/Info.plist")
            runner = archive.getinfo("Payload/Runner.app/Runner")
            mode = stat.S_IFMT(runner.external_attr >> 16)
            if runner.is_dir() or runner.file_size == 0 or mode not in (0, stat.S_IFREG):
                raise ToolError(f"{ipa}：IPA 中缺少有效 Runner 二进制。")
    except (zipfile.BadZipFile, KeyError, RuntimeError, NotImplementedError, zlib.error) as exc:
        raise ToolError(f"{ipa}：IPA 损坏、无法读取或缺少必要文件。") from exc


def package_ios_ipa(root: Path, app: Path, ipa: Path) -> Path:
    if sys.platform != "darwin":
        raise ToolError("IPA 打包需要 macOS 的 cp/zip，以保留现有应用包的文件权限和符号链接。")
    app = build_path(root, app)
    ipa = build_path(root, ipa)
    if app.name != "Runner.app" or not app.is_dir():
        raise ToolError(f"IPA 输入必须是已构建的 Runner.app：{app}")
    if ipa.suffix != ".ipa" or ipa.is_relative_to(app):
        raise ToolError("IPA 输出必须以 .ipa 结尾，且不能写入源 Runner.app。")
    env = os.environ.copy()
    cp = find_tool("cp", env)
    zip_tool = find_tool("zip", env)
    ipa.parent.mkdir(parents=True, exist_ok=True)
    # 每次新建 Payload 和 ZIP，避免旧目录或旧归档中的残余文件混入。
    with tempfile.TemporaryDirectory(prefix=".legado-ipa-", dir=ipa.parent) as temporary:
        stage = Path(temporary)
        payload = stage / "Payload"
        payload.mkdir()
        run_command([cp, "-r", app, payload], stage, env)
        staged_ipa = stage / "app.ipa"
        run_command([zip_tool, "-qry", staged_ipa, "Payload"], stage, env)
        verify_ios_ipa(staged_ipa)
        os.replace(staged_ipa, ipa)
    return ipa


def export_ios_plist(root: Path, app: Path, output: Path):
    output = build_path(root, output)
    app = app.resolve()
    if output.is_relative_to(app) or app.is_relative_to(output):
        raise ToolError("plist 诊断目录不能与源应用目录重叠。")
    source = app / "Info.plist"
    content = source.read_bytes()
    data = plist_data(content, str(source))
    try:
        icons = json.dumps({key: value for key, value in data.items() if "Icon" in key}, indent=2) + "\n"
    except (TypeError, ValueError) as exc:
        raise ToolError("plist 图标区段含不能导出为 JSON 的字段。") from exc
    output.mkdir(parents=True, exist_ok=True)
    for name in ("Info.plist", "icon-section.json"):
        destination = output / name
        if destination.is_symlink():
            raise ToolError(f"诊断输出不能是符号链接：{destination}")
    (output / "Info.plist").write_bytes(content)
    (output / "icon-section.json").write_text(icons, encoding="utf-8")
