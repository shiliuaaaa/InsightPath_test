import os
import logging
from typing import List, Dict

from openai import OpenAI, APIConnectionError

from SQL.client_db import fetch_section_config, fetch_history
from SQL.db import get_db_conn


# 配置日志
logger = logging.getLogger(__name__)

# 获取 API Key，通常从环境变量读取
API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
BASE_URL = "https://api.deepseek.com"  # DeepSeek 的官方 API 地址


def chat_with_deepseek_from_db(section_id: int, user_id: int, content: str) -> str:
    """全流程：连接数据库 -> 取配置与历史 -> 调用大模型，返回回复文本。

    发生业务错误时抛出异常（例如 section 不存在）。
    """
    conn = None
    try:
        conn = get_db_conn()
        section_cfg = fetch_section_config(conn, section_id)
        if not section_cfg:
            raise ValueError("section_id not found")

        history = fetch_history(conn, section_id, user_id, limit=10)
        return ask_deepseek(
            user_query=content,
            system_prompt=section_cfg.get("system_prompt") or "You are a helpful assistant.",
            history=history,
        )
    finally:
        if conn:
            conn.close()



def ask_deepseek(
    user_query: str,
    system_prompt: str = "You are a helpful assistant.",
    history: List[Dict[str, str]] = None,
    model: str = "deepseek-chat",
    temperature: float = 1.3
) -> str:
    """
    向 DeepSeek 发起提问并获取回复。唯一的核心功能函数。

    Args:
        user_query (str): 用户当前的提问内容。
        system_prompt (str): 系统提示词，定义 AI 的角色和行为。
        history (List[Dict[str, str]]): 历史对话记录，格式为 [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]。
        model (str): 使用的模型名称，默认为 "deepseek-chat"。
        temperature (float): 温度参数，控制随机性，默认为 1.3 (DeepSeek 推荐值)。

    Returns:
        str: AI 的回复内容。如果发生错误，返回包含错误信息的字符串。
    """
    if not API_KEY:
        raise RuntimeError("DEEPSEEK_API_KEY environment variable is not set.")

    if history is None:
        history = []

    # 初始化 OpenAI 客户端 (DeepSeek 兼容 OpenAI SDK)
    client = OpenAI(api_key=API_KEY, base_url=BASE_URL)

    # 构建完整的消息列表
    # 1. 放入系统提示词
    messages = [{"role": "system", "content": system_prompt}]
    
    # 2. 放入历史对话记录 (注意：需要确保 history 格式正确)
    # DeepSeek API 不支持 system 角色出现在中间，所以 history 里通常只包含 user 和 assistant
    valid_roles = {"user", "assistant"}
    for msg in history:
        if msg.get("role") in valid_roles:
            messages.append(msg)
    
    # 3. 放入当前用户提问
    messages.append({"role": "user", "content": user_query})

    logging.info(f"Sending request to DeepSeek API with model: {model}")
    try:
        response = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=temperature,
            stream=False,
        )
    except APIConnectionError as exc:
        logger.exception("DeepSeek API connection failed")
        raise RuntimeError("连接大模型服务失败，请稍后重试或检查网络/防火墙/代理设置") from exc

    # 提取回复内容
    answer = response.choices[0].message.content
    return answer
