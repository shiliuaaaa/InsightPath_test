from fastapi import FastAPI

from api.chat_routes import router as chat_router
from utils.logger import setup_logging

app = FastAPI(title="AI Service", version="1.0.0")

logger = setup_logging()
logger.info("Application starting...")
logger.info("Log system initialized.")


@app.get("/health")
def health_check():
    return {"status": "ok"}


# 挂载路由
app.include_router(chat_router, tags=["AI Chat"])

