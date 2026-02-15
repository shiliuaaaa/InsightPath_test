#!/bin/bash

# 获取脚本所在目录，确保在 backend 目录下执行 docker compose
cd "$(dirname "$0")"

function show_help {
    echo "使用方法: ./dev.sh [command]"
    echo "Commands:"
    echo "  python   - 单独启动或重启 Python AI 服务 (及依赖)"
    echo "  java     - 单独启动或重启 Java 后端服务 (及依赖)"
    echo "  db       - 启动数据库服务"
    echo "  all      - 启动所有服务"
}

if [ -z "$1" ]; then
    show_help
    exit 1
fi

case "$1" in
    "python")
        echo "------ 正在构建并启动 Python 服务 ------"
        # --build 强制重新构建镜像，以防代码变更未生效
        docker compose up --build python
        ;;
    "java")
        echo "------ 正在构建并启动 Java 服务 ------"
        # 注意：docker-compose.yml 中 service name 是 backend
        docker compose up --build java
        ;;
    "db")
        echo "------ 正在启动数据库 ------"
        docker compose up -d db
        ;;
    "all")
        echo "------ 正在启动所有服务 ------"
        docker compose up --build
        ;;
    *)
        show_help
        ;;
esac
