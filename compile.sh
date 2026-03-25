#!/bin/bash
# 编译整个项目（Java 后端 + Flutter 前端）
# 用法: ./compile.sh [all|backend|frontend]
# 默认编译全部

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMAND="${1:-all}"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 编译 Java 后端
compile_java() {
    print_info "=========================================="
    print_info "编译 Java 后端"
    print_info "=========================================="
    
    cd "$SCRIPT_DIR/backend/java/src/demo"
    
    print_info "切换到 Java 17..."
    export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home
    export PATH="$JAVA_HOME/bin:$PATH"
    
    print_info "当前 Java 版本："
    java -version
    
    echo ""
    print_info "开始编译..."
    ./mvnw clean compile
    
    if [ $? -eq 0 ]; then
        print_success "Java 后端编译成功！"
        return 0
    else
        print_error "Java 后端编译失败"
        return 1
    fi
}

# 编译 Flutter 前端
compile_flutter() {
    print_info "=========================================="
    print_info "编译 Flutter 前端"
    print_info "=========================================="
    
    FLUTTER_DIR="$SCRIPT_DIR/frontend/src/my_first_app"
    
    if [ ! -d "$FLUTTER_DIR" ]; then
        print_error "Flutter 项目目录不存在: $FLUTTER_DIR"
        return 1
    fi
    
    cd "$FLUTTER_DIR"
    
    # 检查 Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter 未安装"
        return 1
    fi
    
    print_info "当前 Flutter 版本："
    flutter --version
    
    echo ""
    print_info "获取依赖..."
    flutter pub get
    
    if [ $? -ne 0 ]; then
        print_error "获取 Flutter 依赖失败"
        return 1
    fi
    
    echo ""
    print_info "开始编译..."
    flutter build web
    
    if [ $? -eq 0 ]; then
        print_success "Flutter 前端编译成功！"
        return 0
    else
        print_error "Flutter 前端编译失败"
        return 1
    fi
}

# 主函数
main() {
    echo ""
    print_info "=========================================="
    print_info "项目编译脚本"
    print_info "=========================================="
    echo ""
    
    JAVA_RESULT=0
    FLUTTER_RESULT=0
    
    case "$COMMAND" in
        all)
            compile_java
            JAVA_RESULT=$?
            echo ""
            compile_flutter
            FLUTTER_RESULT=$?
            ;;
        backend)
            compile_java
            JAVA_RESULT=$?
            ;;
        frontend)
            compile_flutter
            FLUTTER_RESULT=$?
            ;;
        *)
            print_error "未知命令: $COMMAND"
            echo ""
            echo "用法: ./compile.sh [all|backend|frontend]"
            echo "  all      - 编译全部（默认）"
            echo "  backend  - 仅编译 Java 后端"
            echo "  frontend - 仅编译 Flutter 前端"
            exit 1
            ;;
    esac
    
    echo ""
    print_info "=========================================="
    
    if [ $JAVA_RESULT -eq 0 ] && [ $FLUTTER_RESULT -eq 0 ]; then
        print_success "编译完成！"
        exit 0
    else
        print_error "编译过程中出现错误"
        exit 1
    fi
}

main

