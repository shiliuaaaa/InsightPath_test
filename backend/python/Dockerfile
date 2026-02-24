# 使用轻量级 Python 3.10 镜像
FROM python:3.10-slim

# 设置工作目录
WORKDIR /app

# 先复制依赖文件（利用 Docker 缓存层加速构建）
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制其余代码
COPY . .

# 暴露端口 (FastAPI 默认 8000)
EXPOSE 5000

# 1 代表 True，告诉 Python：标准输出直接打印，不要缓存
# 添加 PYTHONPATH 以便 uvicorn 运行时能找到 src 下的包 (api/utils/Client/...)
ENV PYTHONUNBUFFERED=1 \
	PYTHONPATH=/app/src

# 启动命令：运行 FastAPI 服务
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "5000"]