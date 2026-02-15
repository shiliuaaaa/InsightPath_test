# 使用轻量级 Python 3.10 镜像
FROM python:3.10-slim

# 设置工作目录
WORKDIR /app

# 先复制依赖文件（利用 Docker 缓存层加速构建）
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制其余代码
COPY . .

# 暴露端口 (假设 Python 服务跑在 5000 端口)
EXPOSE 5000

# 1 代表 True，告诉 Python：标准输出直接打印，不要缓存
ENV PYTHONUNBUFFERED=1

# 启动命令 (假设使用 uvicorn 运行 FastAPI，或者 python main.py)
CMD ["python", "src/main.py"]