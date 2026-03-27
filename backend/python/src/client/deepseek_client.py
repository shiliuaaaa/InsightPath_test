import json
import logging
import os
import re
from typing import Any, Dict, List

from openai import AsyncOpenAI, OpenAI, APIConnectionError, BadRequestError

from SQL.client_db import fetch_section_config, fetch_history
from SQL.db import get_db_conn


# 配置日志
logger = logging.getLogger("AIService")

# 固定使用 DeepSeek（OpenAI 兼容接口）
API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
BASE_URL = os.getenv("LLM_BASE_URL", "https://api.deepseek.com")
DEFAULT_MODEL = os.getenv("LLM_MODEL", "deepseek-reasoner")


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
    model: str = DEFAULT_MODEL,
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
        raise RuntimeError("LLM API key is not set. Please configure DEEPSEEK_API_KEY.")

    if history is None:
        history = []

    client = OpenAI(api_key=API_KEY, base_url=BASE_URL)

    messages = [{"role": "system", "content": system_prompt}]
    valid_roles = {"user", "assistant"}
    for msg in history:
        if msg.get("role") in valid_roles:
            messages.append(msg)
    messages.append({"role": "user", "content": user_query})

    logger.info("Sending request to LLM API with model: %s", model)
    try:
        response = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=temperature,
            stream=False,
        )
    except BadRequestError as exc:
        logger.exception("LLM model bad request")
        raise RuntimeError(f"模型不可用（{model}），请检查模型名称或 API Key 权限") from exc
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
        raise RuntimeError("LLM API key is not set. Please configure DEEPSEEK_API_KEY.")

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
            model=DEFAULT_MODEL,
            messages=final_messages,
            temperature=0.9,
            stream=False,
        )
    except BadRequestError as exc:
        logger.exception("LLM model bad request in global tutor")
        raise RuntimeError(f"全局助教模型不可用（{DEFAULT_MODEL}），请检查模型名称或 API Key 权限") from exc
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
你是“灵犀知径”DS&A 动画 DSL V4.0 生成引擎。请把用户需求转成“纯 JSON 动画剧本”。
你必须只输出 JSON，不要输出任何解释、注释、Markdown 代码块。

顶层结构：
{
  "version": "4.0",
  "title": string,
  "scene": "array_sort" | "tree" | "graph" | "dp",
  "steps": AnimationStep[]
}

AnimationStep:
{
  "step_index": number,
  "narration": string,
  "actions": Action[]
}

Action 支持：
1) CREATE
{
  "action": "CREATE",
  "entity_id": string,
  "type": "ArrayNode" | "DataNode" | "Pointer" | "TreeNode" | "GraphNode" | "ArrayContainer",
  "value"?: string,
  "index"?: [number, number],
  "pos"?: number,
  "target_id"?: string,
  "theme"?: "default" | "active" | "locked" | "warning" | "highlight_red" | "locked_green"
}

2) UPDATE
{
  "action": "UPDATE",
  "entity_id": string,
  "theme"?: "default" | "active" | "locked" | "warning" | "highlight_red" | "locked_green",
  "target_id"?: string,
  "index"?: [number, number],
  "value"?: string
}

3) SWAP
{
  "action": "SWAP",
  "entity_id_1": string,
  "entity_id_2": string
}

4) DELETE
{
  "action": "DELETE",
  "entity_id": string
}

5) CONNECT_EDGE
{
  "action": "CONNECT_EDGE",
  "source_entity_id": string,
  "target_id": string,
  "type": "parent_child" | "graph_edge",
  "is_directed"?: boolean,
  "label"?: string,
  "theme"?: "default" | "active" | "locked"
}

6) DISCONNECT
{
  "action": "DISCONNECT",
  "source_entity_id": string,
  "target_id": string
}

7) UPDATE_CELL
{
  "action": "UPDATE_CELL",
  "row": number,
  "col": number,
  "value": string,
  "theme"?: "default" | "active" | "warning" | "locked",
  "entity_id"?: string
}

关键约束：
- 排序/一维数组场景必须设置 scene="array_sort"。
- 在 array_sort 中，ArrayNode（或 DataNode）必须显式给出 pos（整数槽位），不要省略。
- 在 array_sort 中，你必须在“内部状态”维护 entity_id -> current_pos 映射；每次比较/交换前先按已有 SWAP 结果更新映射，再基于 current_pos 选取比较对象。
- 在 array_sort 中，SWAP 表示交换两个可移动数组节点的位置（不是交换 value 文本），且 SWAP 的两个节点必须是当前相邻位置。
- 你在树/图题目中必须使用 TreeNode/GraphNode + CONNECT_EDGE 表达拓扑关系。
- 红黑树等树结构必须显式给出父子边（type=parent_child）。
- entity_id 全局稳定：CREATE 后后续 UPDATE/SWAP/DELETE/CONNECT 用同一 ID。
- 输出必须是可被 JSON.parse 直接解析的纯 JSON。
""".strip()


def _extract_json(raw: str) -> Dict[str, Any]:
    """从大模型原始输出中提取 JSON，容错处理 Markdown 代码块包裹。"""
    # 去除可能的 ```json ... ``` 或 ``` ... ``` 包裹
    cleaned = re.sub(r"^```(?:json)?\s*", "", raw.strip(), flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*```$", "", cleaned.strip())
    return json.loads(cleaned)


def _validate_array_sort_swap_adjacency(script: Dict[str, Any]) -> None:
    """array_sort 额外校验：SWAP 两节点必须是当前相邻位置。"""
    if script.get("scene") != "array_sort":
        return

    entity_pos: Dict[str, int] = {}

    for step in script.get("steps", []):
        actions = step.get("actions", []) if isinstance(step, dict) else []
        step_index = step.get("step_index") if isinstance(step, dict) else "?"

        for action in actions:
            if not isinstance(action, dict):
                continue

            action_type = action.get("action")
            if action_type == "CREATE" and action.get("type") in {"DataNode", "ArrayNode"}:
                entity_id = action.get("entity_id")
                pos = action.get("pos")
                if isinstance(entity_id, str) and isinstance(pos, int):
                    entity_pos[entity_id] = pos

            elif action_type == "SWAP":
                id1 = action.get("entity_id_1")
                id2 = action.get("entity_id_2")
                if not isinstance(id1, str) or not isinstance(id2, str):
                    continue

                if id1 not in entity_pos or id2 not in entity_pos:
                    raise ValueError(
                        f"array_sort SWAP references unknown entity position at step={step_index}: {action}"
                    )

                pos1 = entity_pos[id1]
                pos2 = entity_pos[id2]
                if abs(pos1 - pos2) != 1:
                    raise ValueError(
                        f"array_sort SWAP must swap adjacent positions, got {id1}@{pos1} and {id2}@{pos2} at step={step_index}"
                    )

                entity_pos[id1], entity_pos[id2] = pos2, pos1


def _validate_script(script: Dict[str, Any]) -> None:
    """DSL V4.0 结构校验，字段不合法时抛出 ValueError。"""
    if not isinstance(script.get("title"), str):
        raise ValueError("script.title must be a string")

    scene = script.get("scene")
    allowed_scenes = {"array_sort", "tree", "graph", "dp"}
    if not isinstance(scene, str) or scene not in allowed_scenes:
        raise ValueError(f"script.scene must be one of {sorted(allowed_scenes)}")

    steps = script.get("steps")
    if not isinstance(steps, list) or len(steps) == 0:
        raise ValueError("script.steps must be a non-empty list")

    allowed_actions = {
        "CREATE",
        "UPDATE",
        "SWAP",
        "DELETE",
        "CONNECT_EDGE",
        "CONNECT",      # 兼容旧输出，前端会按 CONNECT_EDGE 解析
        "DISCONNECT",
        "UPDATE_CELL",
    }

    for step in steps:
        if not isinstance(step, dict):
            raise ValueError(f"step must be object, got: {step}")

        if not isinstance(step.get("step_index"), int):
            raise ValueError(f"step_index must be int, got: {step}")

        if not isinstance(step.get("narration"), str):
            raise ValueError(f"narration must be str, got: {step}")

        actions = step.get("actions")
        if not isinstance(actions, list) or len(actions) == 0:
            raise ValueError(f"actions must be non-empty list, got: {step}")

        for action in actions:
            if not isinstance(action, dict):
                raise ValueError(f"action must be object, got: {action}")

            action_type = action.get("action")
            if action_type not in allowed_actions:
                raise ValueError(f"unsupported action type: {action_type}")

            if action_type == "CREATE":
                entity_id = action.get("entity_id")
                node_type = action.get("type")
                if not isinstance(entity_id, str) or not entity_id.strip():
                    raise ValueError(f"CREATE requires non-empty entity_id: {action}")
                if not isinstance(node_type, str) or not node_type.strip():
                    raise ValueError(f"CREATE requires type: {action}")

                if scene == "array_sort" and node_type in {"DataNode", "ArrayNode"}:
                    pos = action.get("pos")
                    if not isinstance(pos, int):
                        raise ValueError(
                            f"array_sort CREATE {node_type} requires int pos: {action}"
                        )

            elif action_type == "UPDATE":
                if not isinstance(action.get("entity_id"), str) or not action["entity_id"].strip():
                    raise ValueError(f"UPDATE requires non-empty entity_id: {action}")

            elif action_type == "SWAP":
                if not isinstance(action.get("entity_id_1"), str) or not isinstance(action.get("entity_id_2"), str):
                    raise ValueError(f"SWAP requires entity_id_1 and entity_id_2: {action}")

            elif action_type == "DELETE":
                if not isinstance(action.get("entity_id"), str) or not action["entity_id"].strip():
                    raise ValueError(f"DELETE requires non-empty entity_id: {action}")

            elif action_type in ("CONNECT_EDGE", "CONNECT", "DISCONNECT"):
                source_id = action.get("source_entity_id") or action.get("source_id")
                target_id = action.get("target_id")
                if not isinstance(source_id, str) or not source_id.strip():
                    raise ValueError(f"{action_type} requires source_entity_id/source_id: {action}")
                if not isinstance(target_id, str) or not target_id.strip():
                    raise ValueError(f"{action_type} requires target_id: {action}")

            elif action_type == "UPDATE_CELL":
                if not isinstance(action.get("row"), int):
                    raise ValueError(f"UPDATE_CELL requires int row: {action}")
                if not isinstance(action.get("col"), int):
                    raise ValueError(f"UPDATE_CELL requires int col: {action}")
                if not isinstance(action.get("value"), str):
                    raise ValueError(f"UPDATE_CELL requires string value: {action}")

    _validate_array_sort_swap_adjacency(script)


async def generate_animation_script(
    prompt: str,
    model: str = DEFAULT_MODEL,
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
        raise RuntimeError("LLM API key is not set. Please configure DEEPSEEK_API_KEY.")

    client = AsyncOpenAI(api_key=API_KEY, base_url=BASE_URL)
    messages = [
        {"role": "system", "content": _ANIMATION_SYSTEM_PROMPT},
        {"role": "user", "content": prompt},
    ]

    last_error: Exception = None
    last_parsed_script: Dict[str, Any] | None = None
    total_attempts = 2

    for attempt in range(1, total_attempts + 1):
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
            last_parsed_script = script
            _validate_script(script)

            # 关键日志：便于快速判断是否真的生成了拓扑动作
            step_count = len(script.get("steps", []))
            action_preview = []
            for step in script.get("steps", [])[:3]:
                actions = step.get("actions", []) if isinstance(step, dict) else []
                action_preview.append([a.get("action") for a in actions if isinstance(a, dict)])
            logger.info(
                "Animation script generated successfully on attempt %d, steps=%d, action_preview=%s",
                attempt,
                step_count,
                action_preview,
            )
            logger.debug("Animation script full payload: %s", json.dumps(script, ensure_ascii=False))
            return script
        except (json.JSONDecodeError, ValueError, KeyError) as exc:
            last_error = exc
            logger.warning(
                "Animation script parse/validate failed on attempt %d: %s",
                attempt,
                exc,
            )

            if attempt == total_attempts and last_parsed_script is not None:
                logger.warning(
                    "⚠️ 第二次重生成仍未通过严格校验，已按降级策略直接使用第二次脚本进行演示。error=%s",
                    exc,
                )
                return last_parsed_script

            # 把失败的输出追加到对话，让模型自我修正
            messages.append({"role": "assistant", "content": raw})
            messages.append({
                "role": "user",
                "content": (
                    f"你的输出解析失败，错误：{exc}。"
                    "请重新输出，严格遵守纯 JSON 格式，不要包含任何 Markdown 符号或解释文字。"
                    "对于 array_sort：必须在内部维护 entity_id->current_pos 映射，"
                    "每次比较和 SWAP 前先基于历史 SWAP 更新 current_pos；"
                    "SWAP 的两个节点必须是当前相邻位置。"
                ),
            })

    raise RuntimeError(
        f"大模型多次生成的动画剧本均不符合 DSL 协议，最后一次错误：{last_error}"
    )
