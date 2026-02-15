import time
import logging
import os
from logging.handlers import RotatingFileHandler

# --- 日志配置 ---
# 1. 确保日志目录存在
log_dir = "/app/logs"
if not os.path.exists(log_dir):
    os.makedirs(log_dir)

# 2. 设置日志文件路径
log_file_path = os.path.join(log_dir, "app.log")

# 3. 获取 logger
logger = logging.getLogger("MyService")
logger.setLevel(logging.INFO)

# 4. 创建 Handler - 写入文件 (支持轮转，防止文件过大)
# maxBytes=10MB, backupCount=5 (保留5个备份)
file_handler = RotatingFileHandler(log_file_path, maxBytes=10*1024*1024, backupCount=5, encoding='utf-8')
file_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))

# 5. 创建 Handler - 输出到控制台 (方便 docker logs 查看)
console_handler = logging.StreamHandler()
console_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))

# 6. 添加 Handler
logger.addHandler(file_handler)
logger.addHandler(console_handler)

logger.info("Application starting...")
logger.info("Log system initialized.")

while True:
    logger.info("Hello World - Running status check")
    time.sleep(1)