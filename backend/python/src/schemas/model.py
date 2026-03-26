from typing import Any, Dict, List

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
