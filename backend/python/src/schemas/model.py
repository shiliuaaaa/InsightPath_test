from typing import Any, Dict, List,Optional#新增Optional

import httpx
from pydantic import BaseModel

class ChatRequest(BaseModel):
    section_id: int
    user_id: int
    content: str


class AnimationGenerateRequest(BaseModel):
    prompt: str


class AnimationGenerateResponse(BaseModel):
    script: Dict[str, Any]


class SocraticChatRequest(BaseModel):
    question: str


class ChatMessage(BaseModel):
    role: str
    content: str


class GlobalChatRequest(BaseModel):
    messages: List[ChatMessage]


class WebSearchResult(BaseModel):
    title: str
    snippet: str
    link: str

#新增
class DocumentParseRequest(BaseModel):
    file_url: str
    document_id: int

class DocumentChunk(BaseModel):
    page_number: int
    content: str
    chunk_type: str  # title, paragraph, formula, list, table
    normalized_coords: List[float]  # [x0, y0, x1, y1]

class DocumentParseResponse(BaseModel):
    chunks: List[DocumentChunk]
    status: str

class RagSearchRequest(BaseModel):
    query: str
    document_id: int  # 对应course_files.id
    top_k: int = 5

class SearchReference(BaseModel):
    chunk_id: str
    content: str
    page_number: int
    coordinates: List[float]  # [x0, y0, x1, y1]
    confidence_score: float

class RagSearchResponse(BaseModel):
    answer: str
    references: List[SearchReference]

class ChatMessage(BaseModel):
    role: str
    content: str

class GlobalChatRequest(BaseModel):
    messages: List[ChatMessage]