"""统一原生指纹与 CI 的文件归属；未知工具保守影响全部原生平台。"""


PLATFORMS = ("android", "windows", "ios")
NATIVE_COMMON = (
    "scripts/tooling/__init__.py",
    "scripts/tooling/common.py",
    "scripts/tooling/contracts.py",
    "scripts/tooling/fingerprint.py",
    "scripts/tooling/input_scopes.py",
    "scripts/tooling/toolchains.py",
)
NATIVE_PLATFORM = {
    "android": (
        "scripts/tooling/android.py",
        "scripts/tooling/android_toolchain.py",
        "scripts/tooling/android-policy.json",
        "scripts/tooling/ffi_metadata.py",
        "scripts/tooling/policy.py",
    ),
    "windows": ("scripts/tooling/windows.py",),
    "ios": ("scripts/tooling/ios.py",),
}
PACKAGING_PLATFORM = {
    "android": ("scripts/tooling/android_app.py", "scripts/tooling/mumu.py"),
    "windows": ("scripts/tooling/windows_app.py",),
    "ios": ("scripts/tooling/ios_bundle.py",),
}
TOOL_ONLY = ("scripts/tooling/bridge.py",)
# 已核对 Cargo、build.rs 与 include_*，这两个宿主脚本均不参与原生库编译。
RUST_DRIVERS = {
    "rust/scripts/build-ios.sh": ("ios",),
    "rust/scripts/gen_rar5_fixture.py": ("rust",),
}


def tooling_platforms(path: str) -> tuple[str, ...] | None:
    """None 表示不是工程工具；空元组表示仅需工具回归。"""
    if path == "scripts/dev.py" or path in NATIVE_COMMON:
        return PLATFORMS
    for platform in PLATFORMS:
        if path in NATIVE_PLATFORM[platform] or path in PACKAGING_PLATFORM[platform]:
            return (platform,)
    if path in TOOL_ONLY:
        return ()
    if path.startswith("scripts/tooling/"):
        return PLATFORMS
    return None


def native_paths(platform: str, available: tuple[str, ...]) -> tuple[str, ...]:
    """已知打包/其他平台文件不入库指纹；新增未分类文件默认入所有平台。"""
    known = set(NATIVE_COMMON) | set(TOOL_ONLY)
    for group in (NATIVE_PLATFORM, PACKAGING_PLATFORM):
        for paths in group.values():
            known.update(paths)
    selected = set(NATIVE_COMMON) | set(NATIVE_PLATFORM[platform])
    selected.update(set(available) - known)
    return tuple(sorted(selected))
