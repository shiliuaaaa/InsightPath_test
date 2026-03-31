import os
from typing import Dict, List

import psycopg2

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

# 新增：RAG函数
def insert_document_chunks(conn, document_id: int, chunks: List[Dict]) -> None:
    """批量插入文档文本块"""
    with conn.cursor() as cur:
        for chunk in chunks:
            cur.execute("""
                INSERT INTO document_text_chunks 
                (document_id, page_number, content, chunk_type, normalized_coords, embedding_vector)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (
                document_id,
                chunk['page_number'],
                chunk['content'],
                chunk['chunk_type'],
                chunk['normalized_coords'],
                chunk.get('embedding_vector')  # 可能为None，后续异步计算
            ))
        conn.commit()

def update_document_parsed_status(conn, document_id: int, status: str) -> None:
    """更新文档解析状态"""
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE course_files SET parsed_status = %s WHERE id = %s
        """, (status, document_id))
        conn.commit()

def semantic_search_chunks(conn, query_embedding: List[float], document_id: int, top_k: int = 5) -> List[Dict]:
    """语义向量搜索"""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, content, page_number, normalized_coords,
                   (embedding_vector <=> %s::vector) AS distance
            FROM document_text_chunks 
            WHERE document_id = %s AND embedding_vector IS NOT NULL
            ORDER BY distance ASC
            LIMIT %s
        """, (query_embedding, document_id, top_k))
        rows = cur.fetchall()
        return [{'id': row[0], 'content': row[1], 'page_number': row[2], 
                'normalized_coords': row[3], 'distance': row[4]} for row in rows]

def keyword_search_chunks(conn, query: str, document_id: int, top_k: int = 5) -> List[Dict]:
    """关键词搜索（使用pg_jieba）"""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, content, page_number, normalized_coords,
                   ts_rank_cd(to_tsvector('jiebacfg', content), plainto_tsquery('jiebacfg', %s)) AS rank
            FROM document_text_chunks 
            WHERE document_id = %s 
            AND to_tsvector('jiebacfg', content) @@ plainto_tsquery('jiebacfg', %s)
            AND rank > 0
            ORDER BY rank DESC
            LIMIT %s
        """, (query, document_id, query, top_k))
        rows = cur.fetchall()
        return [{'id': row[0], 'content': row[1], 'page_number': row[2], 
                'normalized_coords': row[3], 'rank': row[4]} for row in rows]

def get_chunk_by_id(conn, chunk_id: int) -> Dict[str, Any] | None:
    """根据ID获取文本块详情"""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, content, page_number, normalized_coords, document_id
            FROM document_text_chunks 
            WHERE id = %s
        """, (chunk_id,))
        row = cur.fetchone()
        if row:
            return {'id': row[0], 'content': row[1], 'page_number': row[2], 
                    'normalized_coords': row[3], 'document_id': row[4]}
        return None