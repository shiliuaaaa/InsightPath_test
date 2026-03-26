import logging

import httpx
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


@router.get("/api/v1/web/search")
async def web_search(query: str):
    q = (query or "").strip()
    if not q:
        return {"code": 200, "message": "success", "data": {"results": []}}

    url = "https://api.duckduckgo.com/"
    params = {
        "q": q,
        "format": "json",
        "no_redirect": "1",
        "no_html": "1",
        "skip_disambig": "1",
    }

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(url, params=params)
        if resp.status_code != 200:
            raise HTTPException(status_code=503, detail="web search unavailable")

        payload = resp.json()
        related = payload.get("RelatedTopics", [])
        results = []

        def append_item(item):
            if not isinstance(item, dict):
                return
            text = item.get("Text")
            link = item.get("FirstURL")
            if isinstance(text, str) and text.strip() and isinstance(link, str) and link.strip():
                title = text.split(" - ", 1)[0].strip()
                results.append({
                    "title": title or text[:40],
                    "snippet": text.strip(),
                    "link": link.strip(),
                })

        for entry in related:
            if isinstance(entry, dict) and isinstance(entry.get("Topics"), list):
                for sub in entry["Topics"]:
                    append_item(sub)
                    if len(results) >= 5:
                        break
            else:
                append_item(entry)
            if len(results) >= 5:
                break

        return {"code": 200, "message": "success", "data": {"results": results}}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("web search error")
        raise HTTPException(status_code=503, detail="web search unavailable") from e


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
