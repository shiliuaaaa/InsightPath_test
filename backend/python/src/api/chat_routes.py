import logging
from fastapi import APIRouter, HTTPException

from schemas.model import (
    AnimationGenerateRequest,
    AnimationGenerateResponse,
    ChatRequest,
    GlobalChatRequest,
    SocraticChatRequest,
)
from client.deepseek_client import (
    ask_socratic_tutor,
    chat_with_deepseek_from_db,
    chat_with_global_tutor,
    generate_animation_script,
)

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
    except RuntimeError as e:
        # 外部服务连接失败等可恢复错误
        raise HTTPException(status_code=503, detail=str(e)) from e
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error processing chat request")
        raise HTTPException(status_code=500, detail="internal error") from e


@router.post("/api/v1/chat/socratic")
def socratic_chat(request: SocraticChatRequest):
    logger.info("Received socratic request")
    try:
        answer = ask_socratic_tutor(request.question)
        return {
            "code": 200,
            "message": "success",
            "data": {
                "reply": answer,
                "model_version": "deepseek-chat",
            },
        }
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error processing socratic request")
        raise HTTPException(status_code=500, detail="internal error") from e


@router.post("/api/v1/chat/global")
async def global_chat(request: GlobalChatRequest):
    logger.info("Received global chat request, messages=%s", len(request.messages))
    try:
        message_dicts = [{"role": msg.role, "content": msg.content} for msg in request.messages]
        reply_text = await chat_with_global_tutor(message_dicts)
        return {
            "code": 200,
            "message": "success",
            "data": {
                "reply": reply_text,
            },
        }
    except RuntimeError as e:
        logger.exception("Global chat runtime error")
        raise HTTPException(status_code=503, detail=str(e)) from e
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error processing global chat request")
        raise HTTPException(status_code=500, detail="internal error") from e


@router.post("/api/v1/chat/animation", response_model=dict)
async def generate_animation(request: AnimationGenerateRequest):
    """根据用户自然语言 prompt 生成 DSL 动画剧本。"""
    logger.info("Received animation generation request: prompt=%r", request.prompt[:80])
    try:
        script = await generate_animation_script(request.prompt)
        return {
            "code": 200,
            "message": "success",
            "data": AnimationGenerateResponse(script=script).model_dump(),
        }
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e
    except Exception as e:
        logger.exception("Error generating animation script")
        raise HTTPException(status_code=500, detail="internal error") from e
