from pydantic import BaseModel


class ChatRequest(BaseModel):
    section_id: int
    user_id: int
    content: str
