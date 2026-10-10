#!/bin/bash
# generate-bridge.sh — 运行 flutter_rust_bridge 代码生成
# 用法: ./generate-bridge.sh

set -e

# 切到 flutter_legado 目录
cd "$(dirname "$0")/.."

echo "=== flutter_rust_bridge Code Generation ==="
echo "Working dir: $(pwd)"
echo ""

# 从已固定的 Dart runtime 版本读取生成器要求。
frb_version=$(sed -nE 's/^  flutter_rust_bridge: ([0-9]+\.[0-9]+\.[0-9]+)\r?$/\1/p' pubspec.yaml)
if [[ -z "$frb_version" ]]; then
    echo "pubspec.yaml 必须精确固定 flutter_rust_bridge 版本"
    exit 1
fi

# 检查 flutter_rust_bridge_codegen 是否已安装且与 runtime 配对。
if ! command -v flutter_rust_bridge_codegen &>/dev/null; then
    echo "缺少 FRB 生成器，请运行："
    echo "  cargo install flutter_rust_bridge_codegen --version $frb_version --locked"
    exit 1
fi
if [[ "$(flutter_rust_bridge_codegen --version)" != "flutter_rust_bridge_codegen $frb_version" ]]; then
    echo "FRB 生成器版本必须为 $frb_version，请运行："
    echo "  cargo install flutter_rust_bridge_codegen --version $frb_version --locked"
    exit 1
fi

echo ">> Running codegen..."
flutter_rust_bridge_codegen generate

echo ">> 重建 Rust FFI 原生库（保持 hash 配对与 QuickJS 功能）..."
(cd ../rust && cargo build --locked -p legado-ffi --features quickjs)

echo ""
echo "Bridge code generated successfully!"
echo "Generated files are in lib/src/bridge/"
