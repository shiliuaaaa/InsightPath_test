from typing import Dict, List

def fetch_section_config(conn, section_id: int) -> Dict[str, str] | None:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT system_prompt, welcome_message
            FROM section_ai_configs
            WHERE section_id = %s
            """,
            (section_id,),
        )
        row = cur.fetchone()
        if not row:
            return None
        return {"system_prompt": row[0], "welcome_message": row[1]}


def fetch_history(conn, section_id: int, user_id: int, limit: int = 10) -> List[Dict[str, str]]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT role, content
            FROM ai_chat_messages
            WHERE section_id = %s AND user_id = %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (section_id, user_id, limit),
        )
        rows = cur.fetchall()
        rows = list(reversed(rows))
        history: List[Dict[str, str]] = []
        for role, content in rows:
            role_lower = role.lower() if role else "user"
            if role_lower not in ("user", "assistant"):
                role_lower = "user"
            history.append({"role": role_lower, "content": content})
        return history
