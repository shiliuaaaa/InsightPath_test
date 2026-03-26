from typing import Any, Dict

from pydantic import BaseModel


class ChatRequest(BaseModel):
    section_id: int
    user_id: int
    content: str


class AnimationGenerateRequest(BaseModel):
    prompt: str


class AnimationGenerateResponse(BaseModel):
    script: Dict[str, Any]
