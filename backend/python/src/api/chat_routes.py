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
logger = logging.getLogger("AIService")


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
                "model_version": "deepseek-reasoner",
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
                "model_version": "deepseek-reasoner",
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
        logger.info("Animation generated: steps=%d", len(script.get("steps", [])))
        preview = []
        for step in script.get("steps", [])[:3]:
            actions = step.get("actions", []) if isinstance(step, dict) else []
            preview.append([a.get("action") for a in actions if isinstance(a, dict)])
        logger.info("Animation action preview(first 3 steps): %s", preview)
        logger.debug("Animation full script payload: %s", script)
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

# 新增
from fastapi import APIRouter, HTTPException, BackgroundTasks
from schemas.model import (
    DocumentParseRequest, DocumentParseResponse, 
    RagSearchRequest, RagSearchResponse
)
from rag_service import process_uploaded_document, rag_semantic_search

@router.post("/api/v1/rag/documents/process")
async def process_document_endpoint(request: DocumentParseRequest, background_tasks: BackgroundTasks):
    """异步处理文档"""
    logger.info(f"Processing document {request.document_id} from {request.file_url}")
    
    # 立即返回开始处理的状态
    background_tasks.add_task(process_uploaded_document, request.document_id, request.file_url)
    
    return {
        "code": 200,
        "message": "Document processing started",
        "data": {
            "document_id": request.document_id,
            "status": "processing"
        }
    }

@router.post("/api/v1/rag/search", response_model=RagSearchResponse)
async def rag_search_endpoint(request: RagSearchRequest):
    """RAG语义搜索"""
    logger.info(f"RAG search for document {request.document_id}, query: {request.query}")
    
    try:
        result = rag_semantic_search(request.query, request.document_id, request.top_k)
        
        return RagSearchResponse(
            answer=result['answer'],
            references=[SearchReference(**ref) for ref in result['references']]
        )
    except Exception as e:
        logger.error(f"RAG search failed: {e}")
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@router.get("/api/v1/rag/chunks/{chunk_id}")
async def get_chunk_detail(chunk_id: int):
    """获取文本块详情"""
    conn = None
    try:
        conn = get_db_conn()
        chunk = get_chunk_by_id(conn, chunk_id)
        if not chunk:
            raise HTTPException(status_code=404, detail="Chunk not found")
        
        return {
            "code": 200,
            "message": "success",
            "data": chunk
        }
    except Exception as e:
        logger.error(f"Get chunk detail failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()