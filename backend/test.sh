#!/bin/bash
set -e

# 确保在 backend 目录执行
cd "$(dirname "$0")"

show_help() {
  cat <<'EOF'
用法:
  ./test.sh python [测试文件]

说明:
  python           确保 python 服务启动，并运行单元测试
  测试文件省略     运行 src/tests 下全部测试 (unittest discover)
  测试文件提供     仅运行指定测试文件，可用以下形式:
                   - test_xxx.py
                   - src/tests/test_xxx.py
                   - /app/src/tests/test_xxx.py (容器内绝对路径)
示例:
  ./test.sh python
  ./test.sh python test_deepseek_client.py
  ./test.sh python src/tests/test_deepseek_client.py
EOF
}

if [ -z "$1" ]; then
  show_help
  exit 1
fi

case "$1" in
  python)
    shift
    target="$1"

    echo "[test] 确保 python 服务已启动..."
    docker compose up -d python

    if [ -z "$target" ]; then
      echo "[test] 运行全部 Python 单元测试 (discover: src/tests)"
      docker compose exec -T python python -m unittest discover -s /app/src/tests -p "test_*.py"
    else
      # 规范化测试路径
      if [[ "$target" == /* ]]; then
        test_path="$target"
      elif [[ "$target" == src/tests/* ]]; then
        test_path="/app/${target#./}"
      else
        test_path="/app/src/tests/$target"
      fi
      echo "[test] 运行指定测试文件: $test_path"
      docker compose exec -T python python -m unittest "$test_path"
    fi
    ;;
  *)
    show_help
    exit 1
    ;;
 esac
