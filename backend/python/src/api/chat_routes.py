import logging
from fastapi import APIRouter, HTTPException

from schemas.model import ChatRequest
from client.deepseek_client import chat_with_deepseek_from_db

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/internal/ai/chat")
def chat(request: ChatRequest):
    logger.info(
        "Received chat request: section_id=%s, user_id=%s", request.section_id, request.user_id
    )
    try:
        answer = chat_with_deepseek_from_db(
            section_id=request.section_id,
            user_id=request.user_id,
            content=request.content,
        )
        return {
            "code": 200,
            "message": "success",
            "data": {
                "reply": answer,
                "tokens_used": None,
                "model_version": "deepseek-chat",
            },
        }
    except ValueError as e:
        # 业务层明确抛出的错误（例如 section 不存在）
        raise HTTPException(status_code=404, detail=str(e)) from e
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error processing chat request")
        raise HTTPException(status_code=500, detail=str(e)) from e
