import time
import logging
import os
import psycopg2
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

# --- 数据库连接检查 ---
def check_db_connection():
    # 获取环境变量，如果没有则使用默认值
    db_host = os.getenv("DB_HOST", "db")
    # 注意这里使用了docker-compose中db服务的配置
    db_name = os.getenv("DB_NAME", "mydatabase")
    db_user = os.getenv("DB_USER", "myuser")
    # 优先从环境变量获取密码，如果没有则尝试默认
    db_pass = os.getenv("DB_PASS", "mypassword") 

    logger.info(f"Checking database connection checks to {db_host}...")
    
    max_retries = 5
    for i in range(max_retries):
        try:
            conn = psycopg2.connect(
                host=db_host,
                database=db_name,
                user=db_user,
                password=db_pass
            )
            cur = conn.cursor()
            
            # 执行查询
            cur.execute("SELECT * FROM test_connection;")
            rows = cur.fetchall()
            
            logger.info("✅ Database connection successful!")
            logger.info(f"Retrieved {len(rows)} rows from test_connection:")
            for row in rows:
                logger.info(f"  - {row}")
                
            cur.close()
            conn.close()
            return True
            
        except psycopg2.OperationalError as e:
            logger.warning(f"Connection attempt {i+1}/{max_retries} failed: {e}")
            logger.info("Retrying in 2 seconds...")
            time.sleep(2)
        except Exception as e:
            logger.error(f"Unexpected error connecting to database: {e}")
            return False
            
    logger.error("❌ Could not connect to database after multiple attempts.")
    return False

# 执行数据库检查
check_db_connection()

while True:
    logger.info("Hello World - Running status check")
    time.sleep(60) # 延长休眠时间，避免刷屏