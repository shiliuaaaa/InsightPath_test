import json
import logging
import os
import re
from typing import Any, Dict, List

from openai import AsyncOpenAI, OpenAI, APIConnectionError

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
    temperature: float = 1.3,
) -> str:
    """
    向 DeepSeek 发起提问并获取回复。

    Args:
        user_query: 用户当前的提问内容。
        system_prompt: 系统提示词，定义 AI 的角色和行为。
        history: 历史对话记录，格式为 [{"role": "user", "content": "..."}, ...]。
        model: 使用的模型名称。
        temperature: 温度参数，控制随机性。

    Returns:
        AI 的回复内容字符串。
    """
    if not API_KEY:
        raise RuntimeError("DEEPSEEK_API_KEY environment variable is not set.")

    if history is None:
        history = []

    client = OpenAI(api_key=API_KEY, base_url=BASE_URL)

    messages = [{"role": "system", "content": system_prompt}]
    valid_roles = {"user", "assistant"}
    for msg in history:
        if msg.get("role") in valid_roles:
            messages.append(msg)
    messages.append({"role": "user", "content": user_query})

    logger.info("Sending request to DeepSeek API with model: %s", model)
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

    return response.choices[0].message.content


_SOCRATIC_SYSTEM_PROMPT = (
    "你现在是“灵犀知径”平台的启发式 AI 助教。学生正在向你请教课后习题。\n"
    "你的最高指令：**绝对、绝对不要直接告诉学生正确答案（不要直接说选A/B/C/D）！**\n"
    "你的任务是：\n"
    "1. 肯定学生的提问。\n"
    "2. 用反问句或举例子的方式，引导他回忆课件里的知识点。\n"
    "3. 每次回答保持简短（50字以内），像真实的老师对话一样，抛出一个小问题让他思考。"
)

GLOBAL_TUTOR_PROMPT = """你现在是“灵犀知径”教育平台的全局 AI 学管师与学术导师，你的名字叫“小犀”。
你的职责是：解答学生关于计算机科学（如数据结构、算法等）的通用问题，提供学习路径规划，以及考研/就业的引导建议。
请保持专业、温和、鼓励的语气。回答应当结构清晰，善用 Markdown 格式（如加粗、列表、代码块）。如果学生感到迷茫，请给予情感上的鼓励。"""


def ask_socratic_tutor(question: str) -> str:
    return ask_deepseek(
        user_query=question,
        system_prompt=_SOCRATIC_SYSTEM_PROMPT,
        history=[],
        temperature=0.8,
    )


async def chat_with_global_tutor(messages: List[dict]) -> str:
    if not API_KEY:
        raise RuntimeError("DEEPSEEK_API_KEY environment variable is not set.")

    valid_roles = {"user", "assistant"}
    final_messages = [{"role": "system", "content": GLOBAL_TUTOR_PROMPT}]

    for msg in messages:
        role = msg.get("role")
        content = msg.get("content")
        if role in valid_roles and isinstance(content, str) and content.strip():
            final_messages.append({"role": role, "content": content})

    if len(final_messages) == 1:
        raise RuntimeError("messages is empty")

    client = AsyncOpenAI(api_key=API_KEY, base_url=BASE_URL)
    try:
        response = await client.chat.completions.create(
            model="deepseek-chat",
            messages=final_messages,
            temperature=0.9,
            stream=False,
        )
    except APIConnectionError as exc:
        logger.exception("DeepSeek API connection failed in global tutor")
        raise RuntimeError("连接大模型服务失败，请稍后重试") from exc
    except Exception as exc:
        logger.exception("DeepSeek API error in global tutor")
        raise RuntimeError("全局助教服务暂不可用") from exc

    reply = response.choices[0].message.content
    if not reply:
        raise RuntimeError("global tutor reply is empty")
    return reply


# ──────────────────────────────────────────────
# DSL 动画剧本生成
# ──────────────────────────────────────────────

_ANIMATION_SYSTEM_PROMPT = r"""
你是一个专业的算法与数据结构动画渲染引擎。你的任务是将用户的描述或代码转化为标准的 JSON 动画剧本。
你必须严格输出 JSON 格式，不要包含任何 Markdown 标记、代码块符号（如 ```json）或解释性文字。
JSON 结构必须严格符合以下 TypeScript 接口定义：

interface AnimationScript { title: string; steps: AnimationStep[]; }
interface AnimationStep { step_index: number; narration: string; actions: Action[]; }

// Action 包含以下四种，字段按需填写，不需要的字段不要出现：
// 1. CREATE: {"action": "CREATE", "entity_id": "唯一字符串ID", "type": "DataNode"|"Pointer", "value": "显示值", "index": [逻辑X, 逻辑Y], "target_id": "指向的entity_id（仅Pointer需要）"}
// 2. UPDATE: {"action": "UPDATE", "entity_id": "唯一ID", "theme": "active"|"highlight_red"|"locked_green", "target_id": "新指向ID（仅Pointer）", "index": [新位置（可选）]}
// 3. SWAP:   {"action": "SWAP", "entity_id_1": "ID1", "entity_id_2": "ID2"}
// 4. DELETE: {"action": "DELETE", "entity_id": "ID"}

约束：
- step_index 从 0 开始，严格递增。
- 每个 step 的 actions 列表不能为空。
- entity_id 在整个剧本中唯一且稳定（一旦 CREATE 后沿用）。
- DataNode 的 index 为 [列, 行]，从 [0,0] 起，列优先排列。
- 输出纯 JSON，不含任何注释、代码块包裹或额外文字。
""".strip()


def _extract_json(raw: str) -> Dict[str, Any]:
    """从大模型原始输出中提取 JSON，容错处理 Markdown 代码块包裹。"""
    # 去除可能的 ```json ... ``` 或 ``` ... ``` 包裹
    cleaned = re.sub(r"^```(?:json)?\s*", "", raw.strip(), flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*```$", "", cleaned.strip())
    return json.loads(cleaned)


def _validate_script(script: Dict[str, Any]) -> None:
    """基础结构校验，字段不合法时抛出 ValueError。"""
    if not isinstance(script.get("title"), str):
        raise ValueError("script.title must be a string")
    steps = script.get("steps")
    if not isinstance(steps, list) or len(steps) == 0:
        raise ValueError("script.steps must be a non-empty list")
    for step in steps:
        if not isinstance(step.get("step_index"), int):
            raise ValueError(f"step_index must be int, got: {step}")
        if not isinstance(step.get("narration"), str):
            raise ValueError(f"narration must be str, got: {step}")
        if not isinstance(step.get("actions"), list) or len(step["actions"]) == 0:
            raise ValueError(f"actions must be non-empty list, got: {step}")


async def generate_animation_script(
    prompt: str,
    model: str = "deepseek-chat",
    max_retries: int = 2,
) -> Dict[str, Any]:
    """调用 DeepSeek，强制生成符合 DSL 协议的 JSON 动画剧本。

    Args:
        prompt: 用户自然语言描述，例如 "演示冒泡排序"。
        model: 使用的模型名称。
        max_retries: JSON 解析/校验失败时的最大重试次数。

    Returns:
        解析后的动画剧本字典。

    Raises:
        RuntimeError: API 连接失败或多次重试后仍无法获得合法 JSON。
    """
    if not API_KEY:
        raise RuntimeError("DEEPSEEK_API_KEY environment variable is not set.")

    client = AsyncOpenAI(api_key=API_KEY, base_url=BASE_URL)
    messages = [
        {"role": "system", "content": _ANIMATION_SYSTEM_PROMPT},
        {"role": "user", "content": prompt},
    ]

    last_error: Exception = None
    for attempt in range(1, max_retries + 2):  # 1 次正常 + max_retries 次重试
        logger.info("generate_animation_script attempt %d, prompt=%r", attempt, prompt[:60])
        try:
            response = await client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=0.0,   # 动画剧本要求确定性输出，temperature 设为 0
                response_format={"type": "json_object"},  # 强制 JSON 模式
                stream=False,
            )
        except APIConnectionError as exc:
            logger.exception("DeepSeek API connection failed on attempt %d", attempt)
            raise RuntimeError("连接大模型服务失败，请稍后重试或检查网络/防火墙/代理设置") from exc

        raw = response.choices[0].message.content
        logger.debug("Raw model output (attempt %d): %s", attempt, raw[:200])

        try:
            script = _extract_json(raw)
            _validate_script(script)
            logger.info("Animation script generated successfully on attempt %d", attempt)
            return script
        except (json.JSONDecodeError, ValueError, KeyError) as exc:
            last_error = exc
            logger.warning(
                "Animation script parse/validate failed on attempt %d: %s", attempt, exc
            )
            # 把失败的输出追加到对话，让模型自我修正
            messages.append({"role": "assistant", "content": raw})
            messages.append({
                "role": "user",
                "content": (
                    f"你的输出解析失败，错误：{exc}。"
                    "请重新输出，严格遵守纯 JSON 格式，不要包含任何 Markdown 符号或解释文字。"
                ),
            })

    raise RuntimeError(
        f"大模型多次生成的动画剧本均不符合 DSL 协议，最后一次错误：{last_error}"
    )
