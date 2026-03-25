import logging
import os
from logging.handlers import RotatingFileHandler


def setup_logging(name: str = "AIService", log_dir: str = None) -> logging.Logger:
    if log_dir is None:
        log_dir = os.environ.get("LOG_DIR", "/tmp/insightpath_logs")
    """Configure rotating file + console logger and return logger instance.

    - log_dir: ensure exists
    - rotating file: app.log, 10MB, keep 5 backups
    - console: same format
    """

    os.makedirs(log_dir, exist_ok=True)
    log_file_path = os.path.join(log_dir, "app.log")

    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)

    fmt = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

    file_handler = RotatingFileHandler(
        log_file_path, maxBytes=10 * 1024 * 1024, backupCount=5, encoding="utf-8"
    )
    file_handler.setFormatter(fmt)

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(fmt)

    if not logger.handlers:
        logger.addHandler(file_handler)
        logger.addHandler(console_handler)

    return logger