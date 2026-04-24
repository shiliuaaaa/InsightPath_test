#!/bin/bash

# 项目启动脚本
# 用法: ./start.sh [all|backend|frontend|java|python]
# 默认启动全部

set -e
PARTIAL_FAILURE=0

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}InsightPath 项目启动脚本${NC}

用法: ./start.sh [选项]

选项:
  all          启动全部服务（默认）
  backend      启动后端服务（Java + Python）
  frontend     启动前端服务（Flutter）
  java         仅启动 Java 后端
  python       仅启动 Python AI 服务
  help         显示此帮助信息

环境变量:
  LLM_MODEL           模型名称（默认 qwen-max）
  LLM_API_KEY         大模型 API Key（兼容阿里云百炼/千问）
  LLM_BASE_URL        OpenAI 兼容接口地址（默认阿里云百炼）
  DB_HOST             数据库主机（默认 localhost）
  DB_NAME            数据库名（默认 mydatabase）
  DB_USER            数据库用户（默认 myuser）
  DB_PASS            数据库密码（默认 mypassword）
  PYTHON_PORT        Python AI 服务端口（默认 5001）

示例:
  ./start.sh                                        # 启动全部
  LLM_API_KEY=sk-xxx ./start.sh
  LLM_MODEL=qwen-max ./start.sh
  ./start.sh backend                                # 启动后端
  ./start.sh java                                   # 仅启动 Java
  ./start.sh frontend                               # 启动前端

EOF
}

# 加载 .env 文件（如果存在）
load_env() {
    local env_file="$SCRIPT_DIR/backend/python/src/.env"
    if [ -f "$env_file" ]; then
        print_info "加载环境变量: $env_file"
        # 逐行读取，跳过注释和空行
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            # 只在未设置时才赋值（允许外部环境变量覆盖）
            if [ -z "${!key}" ]; then
                export "$key"="$value"
            fi
        done < "$env_file"
    fi
}

# 启动 Java 后端
start_java() {
    print_info "启动 Java 后端服务..."
    
    JAVA_DIR="$SCRIPT_DIR/backend/java/src/demo"
    
    if [ ! -d "$JAVA_DIR" ]; then
        print_error "Java 项目目录不存在: $JAVA_DIR"
        return 1
    fi

    # 自动清理占用 8080 端口的进程
    if lsof -ti:8080 >/dev/null 2>&1; then
        print_warning "端口 8080 被占用，正在清理..."
        lsof -ti:8080 | xargs kill -9 2>/dev/null || true
        sleep 1
        print_success "端口 8080 已释放"
    fi
    
    cd "$JAVA_DIR"
    
    # 设置 Java 17
    export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home
    export PATH="$JAVA_HOME/bin:$PATH"
    
    print_info "Java 版本:"
    java -version
    
    print_warning "⚠️  请确保 PostgreSQL 数据库已启动在 localhost:5432"
    echo ""
    
    print_info "启动 Spring Boot 应用..."
    nohup ./mvnw spring-boot:run > /tmp/java_backend.log 2>&1 &
    JAVA_PID=$!
    disown "$JAVA_PID"

    print_info "等待 Java 后端启动..."
    for i in $(seq 1 25); do
        sleep 1
        if lsof -ti:8080 > /dev/null 2>&1; then
            print_success "Java 后端已启动 (PID: $JAVA_PID)"
            print_info "日志: tail -f /tmp/java_backend.log"
            print_info "访问地址: http://localhost:8080"
            return 0
        fi
        if ! kill -0 "$JAVA_PID" 2>/dev/null; then
            break
        fi
    done

    print_error "Java 后端启动失败，请检查日志: /tmp/java_backend.log"
    if [ -f /tmp/java_backend.log ]; then
        tail -n 40 /tmp/java_backend.log
    fi
    return 1
}

# 启动 Python AI 服务
start_python() {
    print_info "启动 Python AI 服务..."
    
    PYTHON_DIR="$SCRIPT_DIR/backend/python/src"
    PYTHON_PORT="${PYTHON_PORT:-5001}"
    
    if [ ! -d "$PYTHON_DIR" ]; then
        print_error "Python 项目目录不存在: $PYTHON_DIR"
        return 1
    fi

    # 检查 LLM API Key
    if [ -z "$LLM_API_KEY" ] && [ -z "$DASHSCOPE_API_KEY" ] && [ -z "$DEEPSEEK_API_KEY" ]; then
        print_error "LLM_API_KEY 未设置！AI 聊天功能将无法使用。"
        print_info "请设置环境变量后重试:"
        print_info "  export LLM_API_KEY=sk-xxxxxxxx"
        print_info "  或在 backend/python/src/.env 文件中配置"
        return 1
    fi
    if [ -z "$LLM_MODEL" ]; then
        export LLM_MODEL="qwen-max"
    fi
    if [ -z "$LLM_BASE_URL" ]; then
        export LLM_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1"
    fi

    # 自动清理占用端口的旧进程
    if lsof -ti:$PYTHON_PORT >/dev/null 2>&1; then
        print_warning "端口 $PYTHON_PORT 被占用，正在清理..."
        lsof -ti:$PYTHON_PORT | xargs kill -9 2>/dev/null || true
        sleep 1
        print_success "端口 $PYTHON_PORT 已释放"
    fi
    
    cd "$PYTHON_DIR"
    
    # 检查 Python 版本
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 未安装"
        return 1
    fi
    
    print_info "Python 版本: $(python3 --version)"
    
    # 检查虚拟环境，不存在或损坏则重建
    if [ ! -d "venv" ] || [ ! -f "venv/pyvenv.cfg" ]; then
        if [ -d "venv" ]; then
            print_warning "检测到损坏的虚拟环境，正在重建..."
            rm -rf "venv"
        else
            print_warning "虚拟环境不存在，正在创建..."
        fi
        python3 -m venv venv || {
            print_error "虚拟环境创建失败"
            return 1
        }
        print_success "虚拟环境已创建"
    fi

    # 兼容不同 Python 版本/venv 结构（有些环境只有 python3.13 / pip3.13）
    VENV_PYTHON=""
    for candidate in "$PYTHON_DIR/venv/bin/python" "$PYTHON_DIR/venv/bin/python3" "$PYTHON_DIR/venv/bin/python3.13"; do
        if [ -x "$candidate" ]; then
            VENV_PYTHON="$candidate"
            break
        fi
    done

    VENV_PIP=""
    for candidate in "$PYTHON_DIR/venv/bin/pip" "$PYTHON_DIR/venv/bin/pip3"; do
        if [ -x "$candidate" ]; then
            VENV_PIP="$candidate"
            break
        fi
    done

    if [ -z "$VENV_PIP" ] && [ -n "$VENV_PYTHON" ]; then
        VENV_PIP="$VENV_PYTHON -m pip"
    fi

    if [ -z "$VENV_PYTHON" ]; then
        print_error "虚拟环境 Python 不存在，请删除 $PYTHON_DIR/venv 后重试"
        return 1
    fi
    
    # 先补齐基础打包工具，避免 Python 3.13 新环境缺少 setuptools/wheel
    print_info "初始化 Python 打包工具..."
    "$VENV_PYTHON" -m ensurepip --upgrade >/dev/null 2>&1 || true
    eval "$VENV_PIP install -q --upgrade pip setuptools wheel" || {
        print_warning "基础打包工具升级失败，继续尝试安装业务依赖..."
    }

    # 安装依赖
    if [ -f "requirements.txt" ]; then
        print_info "检查并安装依赖..."
        eval "$VENV_PIP install -q -r requirements.txt" || {
            print_warning "src/requirements.txt 安装失败，继续尝试补充依赖..."
        }
    fi

    print_info "启动 Python AI 服务 (端口: $PYTHON_PORT)..."

    LLM_API_KEY="${LLM_API_KEY:-${DASHSCOPE_API_KEY:-${DEEPSEEK_API_KEY:-}}}" \
    LLM_MODEL="$LLM_MODEL" \
    LLM_BASE_URL="$LLM_BASE_URL" \
    DB_HOST="${DB_HOST:-localhost}" \
    DB_NAME="${DB_NAME:-mydatabase}" \
    DB_USER="${DB_USER:-myuser}" \
    DB_PASS="${DB_PASS:-mypassword}" \
    nohup "$VENV_PYTHON" -m uvicorn main:app \
        --host 0.0.0.0 \
        --port "$PYTHON_PORT" \
        > /tmp/python_ai.log 2>&1 &
    PYTHON_PID=$!
    disown $PYTHON_PID

    # 等待服务启动并验证
    print_info "等待 Python AI 服务启动..."
    for i in $(seq 1 10); do
        sleep 1
        if curl -s "http://localhost:$PYTHON_PORT/health" | grep -q 'ok' 2>/dev/null; then
            print_success "Python AI 服务已启动 (PID: $PYTHON_PID)"
            print_info "日志: tail -f /tmp/python_ai.log"
            print_info "访问地址: http://localhost:$PYTHON_PORT"
            return 0
        fi
    done

    print_warning "Python AI 服务启动超时，请检查日志: tail -f /tmp/python_ai.log"
    return 1
}

# 启动前端
start_frontend() {
    print_info "启动 Flutter 前端..."
    
    FRONTEND_DIR="$SCRIPT_DIR/frontend/src/InsightPath"
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        print_error "前端项目目录不存在: $FRONTEND_DIR"
        return 1
    fi
    
    cd "$FRONTEND_DIR"
    
    # 检查 Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter 未安装"
        return 1
    fi
    
    print_info "获取依赖..."
    flutter pub get
    
    print_info "启动 Flutter 应用..."
    
    # 检测平台
    if [ "$(uname)" == "Darwin" ]; then
        print_info "在 macOS 上启动..."
        flutter run -d macos &
    elif [ "$(uname)" == "Linux" ]; then
        print_info "在 Linux 上启动..."
        flutter run -d linux &
    else
        print_warning "自动平台检测失败，请手动指定平台"
        print_info "可用命令:"
        print_info "  flutter run -d windows"
        print_info "  flutter run -d web"
        print_info "  flutter run -d android"
        print_info "  flutter run -d ios"
        return 1
    fi
    
    FLUTTER_PID=$!
    print_success "Flutter 前端已启动 (PID: $FLUTTER_PID)"
    
    return 0
}

# 启动后端
start_backend() {
    print_info "启动后端服务..."

    if start_java; then
        JAVA_RESULT=0
    else
        JAVA_RESULT=1
    fi

    if start_python; then
        PYTHON_RESULT=0
    else
        PYTHON_RESULT=1
    fi

    if [ $JAVA_RESULT -eq 0 ] && [ $PYTHON_RESULT -eq 0 ]; then
        print_success "后端服务已启动"
        return 0
    else
        print_error "后端启动过程中出现错误"
        PARTIAL_FAILURE=1
        return 1
    fi
}

# 启动全部
start_all() {
    print_info "启动全部服务..."

    if start_backend; then
        BACKEND_RESULT=0
    else
        BACKEND_RESULT=1
    fi

    # 等待后端启动完成
    sleep 3

    if start_frontend; then
        FRONTEND_RESULT=0
    else
        FRONTEND_RESULT=1
    fi

    if [ $BACKEND_RESULT -eq 0 ] && [ $FRONTEND_RESULT -eq 0 ]; then
        print_success "所有服务已启动"
        return 0
    fi

    if [ $FRONTEND_RESULT -eq 0 ]; then
        print_warning "前端已启动，但后端未完全启动。应用可进入，接口调用会失败。"
        PARTIAL_FAILURE=1
        return 0
    fi

    print_error "启动过程中出现错误"
    return 1
}

# 主函数
main() {
    echo ""
    print_info "=========================================="
    print_info "InsightPath 项目启动脚本"
    print_info "=========================================="
    echo ""

    # 加载 .env 文件
    load_env
    
    # 获取参数，默认为 "all"
    COMMAND="${1:-all}"
    
    case "$COMMAND" in
        all)
            start_all
            ;;
        backend)
            start_backend
            ;;
        frontend)
            start_frontend
            ;;
        java)
            start_java
            ;;
        python)
            start_python
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            print_error "未知命令: $COMMAND"
            echo ""
            show_help
            exit 1
            ;;
    esac
    
    RESULT=$?
    
    echo ""
    if [ $RESULT -eq 0 ]; then
        if [ $PARTIAL_FAILURE -eq 1 ]; then
            print_warning "启动完成（部分服务失败）"
            print_warning "请检查后端日志并修复后重试"
        else
            print_success "启动完成！"
        fi
        print_info "日志查看:"
        print_info "  Java 后端: tail -f /tmp/java_backend.log"
        print_info "  Python AI: tail -f /tmp/python_ai.log"
        print_info "按 Ctrl+C 停止前台进程"
        
        # 保持脚本运行
        wait
    else
        print_error "启动失败"
        exit 1
    fi
}

# 捕获 Ctrl+C 信号
trap 'print_warning "正在停止服务..."; exit 0' INT TERM

# 运行主函数
main "$@"
