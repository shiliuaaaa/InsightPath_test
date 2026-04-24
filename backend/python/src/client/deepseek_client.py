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

# 通用 OpenAI 兼容接口配置（默认切到阿里云百炼 / 千问）
API_KEY = (
    os.getenv("LLM_API_KEY")
    or os.getenv("DASHSCOPE_API_KEY")
    or os.getenv("DEEPSEEK_API_KEY", "")
)
BASE_URL = os.getenv("LLM_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1")
DEFAULT_MODEL = os.getenv("LLM_MODEL", "qwen-max")


def chat_with_llm_from_db(section_id: int, user_id: int, content: str) -> str:
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
        return ask_llm(
            user_query=content,
            system_prompt=section_cfg.get("system_prompt") or "You are a helpful assistant.",
            history=history,
        )
    finally:
        if conn:
            conn.close()


def ask_llm(
    user_query: str,
    system_prompt: str = "You are a helpful assistant.",
    history: List[Dict[str, str]] = None,
    model: str = DEFAULT_MODEL,
    temperature: float = 1.3,
) -> str:
    """
    向当前配置的大模型发起提问并获取回复。

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
        raise RuntimeError("LLM API key is not set. Please configure LLM_API_KEY.")

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
        logger.exception("LLM API connection failed")
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
    return ask_llm(
        user_query=question,
        system_prompt=_SOCRATIC_SYSTEM_PROMPT,
        history=[],
        temperature=0.8,
    )


async def chat_with_global_tutor(messages: List[dict]) -> str:
    if not API_KEY:
        raise RuntimeError("LLM API key is not set. Please configure LLM_API_KEY.")

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
        logger.exception("LLM API connection failed in global tutor")
        raise RuntimeError("连接大模型服务失败，请稍后重试") from exc
    except Exception as exc:
        logger.exception("LLM API error in global tutor")
        raise RuntimeError("全局助教服务暂不可用") from exc

    reply = response.choices[0].message.content
    if not reply:
        raise RuntimeError("global tutor reply is empty")
    return reply


# ──────────────────────────────────────────────
# DSL 动画剧本生成
# ──────────────────────────────────────────────

_ANIMATION_SYSTEM_PROMPT = r"""
你是“灵犀知径”DS&A 动画 DSL V4.0 渲染指令编译器。
你的唯一任务：把用户描述的算法过程，严格编译为可执行的纯 JSON 动画剧本。
你绝对不能输出任何解释文字、注释、Markdown 包裹符或额外说明；你只能输出一个可被 JSON.parse 直接解析的 JSON 对象。

【核心机制：状态草稿本 (thought_process)】
大语言模型没有隐式记忆。为了最大限度保证逻辑正确，你必须在每个 AnimationStep 中新增一个 "thought_process" 字段。
在生成 actions 前，你必须先在这个字段里写下：
1. 当前有哪些变量或指针，它们分别指向哪里；
2. 当前节点的逻辑槽位索引（pos，必须是 0、1、2 等整数）是多少？当前的 ID -> pos 映射关系是什么？
3. 下一步准备执行什么，以及执行后位置如何变化。

【顶层结构】
{
  "version": "4.0",
  "title": string,
  "scene": "array_sort" | "tree" | "graph" | "dp",
  "steps": AnimationStep[]
}

【AnimationStep 结构】
{
  "step_index": number,
  "thought_process": string,
  "narration": string,
  "actions": Action[]
}

【极其重要的结构约束】
- steps 必须是 JSON 数组，不能为空。
- 每个 step 必须是 JSON 对象。
- 每个 step 必须且只能包含 step_index、thought_process、narration、actions 等步骤级字段。
- actions 必须是 JSON 数组（[]），不能为空。
- actions 中的每一项都必须是一个 JSON 对象。
- 所有动作字段，例如 action、entity_id、type、value、pos、target_id、entity_id_1、entity_id_2、source_entity_id，必须写在 actions 数组的元素对象中。
- 严禁在 AnimationStep 顶层直接出现 action、entity_id、type、value、pos、target_id、entity_id_1、entity_id_2、source_entity_id 等动作字段。
- 严禁把 actions 写成字符串、数字、null、对象，或类似 ":[{" 这样的损坏片段。

【Action 支持】
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

【绝对约束】
- 排序/一维数组场景必须设置 scene="array_sort"。
- 在 array_sort 中，ArrayNode（或 DataNode）必须显式给出 pos（整数槽位）。
- 注意：你只需输出整数索引 pos，具体的屏幕坐标转换和布局居中由前端渲染引擎自动处理，你绝对不要输出任何像素值。
- 在 array_sort 中，你必须显式维护 entity_id -> current_pos 映射，并在 thought_process 中写出来；每次比较/交换前，先基于已有 SWAP 历史更新 current_pos，再决定本步操作对象。
- 在 array_sort 中，SWAP 表示交换两个数组节点的位置，而不是交换 value 文本；SWAP 的两个节点必须是当前物理位置完全相邻的两个实体。
- 你在树/图题目中必须使用 TreeNode/GraphNode + CONNECT_EDGE 表达拓扑关系。
- 红黑树等树结构必须显式给出父子边（type=parent_child）。
- entity_id 全局稳定：CREATE 后，后续 UPDATE/SWAP/DELETE/CONNECT 必须继续使用同一 ID。
- 如果某一步没有合法动作，不要输出该步骤；绝对不要输出空的 actions。
- 输出必须是严格合法的 JSON，不能包含残缺括号、截断字符串或半个数组。

【错误示例：以下写法绝对禁止】
{
  "step_index": 1,
  "thought_process": "...",
  "narration": "...",
  "actions": ":[{",
  "action": "CREATE",
  "entity_id": "node_0",
  "type": "DataNode",
  "pos": 0
}
上面这种写法是错误的，因为 action/entity_id/type/pos 被错误地写到了 step 顶层，而且 actions 不是数组。

【黄金示例：输入“请演示冒泡排序交换 [3, 1]”时，输出应类似】
{
  "version": "4.0",
  "title": "冒泡排序",
  "scene": "array_sort",
  "steps": [
    {
      "step_index": 1,
      "thought_process": "初始化。创建 node_0 在 pos=0（值为3），创建 node_1 在 pos=1（值为1）。当前 ID -> pos 映射：node_0 -> 0, node_1 -> 1。",
      "narration": "首先，我们初始化待排序的数组。",
      "actions": [
        {"action": "CREATE", "entity_id": "node_0", "type": "DataNode", "value": "3", "pos": 0},
        {"action": "CREATE", "entity_id": "node_1", "type": "DataNode", "value": "1", "pos": 1}
      ]
    },
    {
      "step_index": 2,
      "thought_process": "比较 pos=0 的 node_0 和 pos=1 的 node_1。当前 ID -> pos 映射：node_0 -> 0, node_1 -> 1。因为 3 > 1，发生相邻交换。交换后 node_0 -> 1，node_1 -> 0。",
      "narration": "比较相邻的两个元素，3 大于 1，我们需要交换它们的位置。",
      "actions": [
        {"action": "UPDATE", "entity_id": "node_0", "theme": "highlight_red"},
        {"action": "UPDATE", "entity_id": "node_1", "theme": "highlight_red"},
        {"action": "SWAP", "entity_id_1": "node_0", "entity_id_2": "node_1"},
        {"action": "UPDATE", "entity_id": "node_0", "theme": "default"},
        {"action": "UPDATE", "entity_id": "node_1", "theme": "default"}
      ]
    }
  ]
}

【输出前自检】
在最终输出前，你必须逐项自检：
1. 顶层是否是单个 JSON 对象，而不是 Markdown。
2. steps 是否是非空数组。
3. 每个 step 是否都包含 step_index、thought_process、narration、actions。
4. 每个 step 的 actions 是否都是非空数组。
5. 是否把任何动作字段错误地写到了 step 顶层。
6. array_sort 中每个 DataNode/ArrayNode 是否都带 int 类型的 pos。
7. 是否输出了任何像素值、坐标字符串、残缺 JSON 片段。
只有全部满足，才允许输出。
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
        raise RuntimeError("LLM API key is not set. Please configure LLM_API_KEY.")

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
