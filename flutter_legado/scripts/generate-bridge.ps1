# generate-bridge.ps1 — 运行 flutter_rust_bridge 代码生成 (Windows)
# 用法: .\generate-bridge.ps1

$ErrorActionPreference = "Stop"

# 切到 flutter_legado 目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FlutterDir = Split-Path -Parent $ScriptDir
Set-Location $FlutterDir

Write-Host "=== flutter_rust_bridge Code Generation ===" -ForegroundColor Cyan
Write-Host "Working dir: $(Get-Location)"
Write-Host ""

# 从已固定的 Dart runtime 版本读取生成器要求。
$Pubspec = Get-Content (Join-Path $FlutterDir "pubspec.yaml") -Raw
$FrbVersionMatch = [regex]::Match($Pubspec, '(?m)^  flutter_rust_bridge:\s*(\d+\.\d+\.\d+)\s*$')
if (-not $FrbVersionMatch.Success) {
    throw "pubspec.yaml 必须精确固定 flutter_rust_bridge 版本"
}
$FrbVersion = $FrbVersionMatch.Groups[1].Value

# 检查 flutter_rust_bridge_codegen 是否已安装且与 runtime 配对。
if (-not (Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue)) {
    Write-Error "缺少 FRB 生成器，请运行：cargo install flutter_rust_bridge_codegen --version $FrbVersion --locked"
    exit 1
}
$CodegenVersion = flutter_rust_bridge_codegen --version
if ($LASTEXITCODE -ne 0 -or "$CodegenVersion".Trim() -ne "flutter_rust_bridge_codegen $FrbVersion") {
    throw "FRB 生成器版本必须为 $FrbVersion，请运行：cargo install flutter_rust_bridge_codegen --version $FrbVersion --locked"
}

Write-Host ">> Running codegen..." -ForegroundColor Yellow
flutter_rust_bridge_codegen generate

if ($LASTEXITCODE -ne 0) {
    Write-Error "Code generation failed"
    exit 1
}

# 关键：codegen 会重新生成两侧 content hash，必须紧跟一次 DLL 重编译，
# 否则运行时报 "Content hash on Dart side ... different from Rust side"。
Write-Host ""
Write-Host ">> Rebuilding Rust FFI DLL (keep hash in sync)..." -ForegroundColor Yellow
$RustDir = Join-Path (Split-Path -Parent $FlutterDir) "rust"
# DLL 可能被运行中的应用锁定，先尝试关闭
Stop-Process -Name "flutter_legado" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Push-Location $RustDir
cargo build --locked -p legado-ffi --features quickjs
$rustExit = $LASTEXITCODE
Pop-Location
if ($rustExit -ne 0) {
    Write-Error "Rust FFI build failed"
    exit 1
}

Write-Host ""
Write-Host "Bridge code generated & DLL rebuilt successfully!" -ForegroundColor Green
Write-Host "Generated files are in lib\src\bridge\"
