#!/bin/bash

set -euo pipefail

# 用法示例：
# ./build_release.sh --server-ip 192.168.1.23 --mode all
# ./build_release.sh --server-ip 192.168.1.23 --mode apk
# ./build_release.sh --server-ip 192.168.1.23 --mode windows

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend/src/InsightPath"

MODE="all" # all | windows | apk
SERVER_IP=""
JAVA_PORT="8080"
PY_PORT="5001"

print_info() {
  echo "[INFO] $1"
}

print_warn() {
  echo "[WARN] $1"
}

print_error() {
  echo "[ERROR] $1"
}

show_help() {
  cat << EOF
InsightPath 一键打包脚本

用法：
  ./build_release.sh --server-ip <你的MacIP> [--mode all|windows|apk] [--java-port 8080] [--py-port 5001]

参数：
  --server-ip   必填，你的 Mac 服务器 IP（例如 192.168.1.23）
  --mode        可选，默认 all
                all     同时尝试打包 windows + apk
                windows 仅打包 Windows EXE
                apk     仅打包 Android APK
  --java-port   可选，默认 8080
  --py-port     可选，默认 5001
  -h, --help    查看帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-ip)
      SERVER_IP="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --java-port)
      JAVA_PORT="$2"
      shift 2
      ;;
    --py-port)
      PY_PORT="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      print_error "未知参数: $1"
      show_help
      exit 1
      ;;
  esac
done

if [[ -z "$SERVER_IP" ]]; then
  print_error "必须提供 --server-ip"
  show_help
  exit 1
fi

if [[ "$MODE" != "all" && "$MODE" != "windows" && "$MODE" != "apk" ]]; then
  print_error "--mode 只支持 all | windows | apk"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  print_error "未找到 flutter，请先安装并配置 Flutter SDK"
  exit 1
fi

API_BASE_URL="http://${SERVER_IP}:${JAVA_PORT}/api/v1"
AI_BASE_URL="http://${SERVER_IP}:${PY_PORT}"

print_info "前端目录: $FRONTEND_DIR"
print_info "API_BASE_URL=$API_BASE_URL"
print_info "AI_BASE_URL=$AI_BASE_URL"

if [[ ! -d "$FRONTEND_DIR" ]]; then
  print_error "前端目录不存在：$FRONTEND_DIR"
  exit 1
fi

cd "$FRONTEND_DIR"

print_info "执行 flutter pub get..."
flutter pub get

build_windows() {
  local os_name
  os_name="$(uname -s)"

  # Windows 构建要求在 Windows 环境下执行
  if [[ "$os_name" != "MINGW64_NT"* && "$os_name" != "MSYS_NT"* && "$os_name" != "CYGWIN_NT"* ]]; then
    print_warn "当前系统不是 Windows，跳过 Windows EXE 打包"
    return 0
  fi

  print_info "开始打包 Windows EXE..."
  flutter build windows --release \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=AI_BASE_URL="$AI_BASE_URL"

  print_info "Windows 产物目录：$FRONTEND_DIR/build/windows/x64/runner/Release"
}

build_apk() {
  print_info "开始打包 Android APK..."
  flutter build apk --release \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=AI_BASE_URL="$AI_BASE_URL"

  print_info "APK 产物：$FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
}

case "$MODE" in
  all)
    build_windows
    build_apk
    ;;
  windows)
    build_windows
    ;;
  apk)
    build_apk
    ;;
esac

print_info "打包流程完成"

