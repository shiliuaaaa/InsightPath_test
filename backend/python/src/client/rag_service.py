import logging
from typing import List, Dict, Any
from SQL.db import get_db_conn
from SQL.client_db import (
    semantic_search_chunks, keyword_search_chunks, 
    get_chunk_by_id, insert_document_chunks, update_document_parsed_status
)
from deepseek_client import ask_deepseek
from .ocr_service import ocr_service

logger = logging.getLogger("AIService")

def process_uploaded_document(document_id: int, file_url: str) -> bool:
    """处理上传的文档，进行OCR分析和向量化"""
    conn = None
    try:
        conn = get_db_conn()
        
        # 更新状态为解析中
        update_document_parsed_status(conn, document_id, "PARSING")
        
        # 分析文档，获取文本块
        chunks = ocr_service.analyze_document(file_url)
        
        # 为每个文本块生成向量
        for chunk in chunks:
            if chunk['content'].strip():  # 只对非空内容生成向量
                embedding = ocr_service.generate_embedding(chunk['content'])
                chunk['embedding_vector'] = embedding
        
        # 保存到数据库
        insert_document_chunks(conn, document_id, chunks)
        
        # 更新状态为已解析
        update_document_parsed_status(conn, document_id, "PARSED")
        
        logger.info(f"Document {document_id} processed successfully with {len(chunks)} chunks")
        return True
        
    except Exception as e:
        logger.error(f"Failed to process document {document_id}: {e}")
        if conn:
            update_document_parsed_status(conn, document_id, "FAILED")
        return False
    finally:
        if conn:
            conn.close()

def rag_semantic_search(query: str, document_id: int, top_k: int = 5) -> Dict[str, Any]:
    """执行RAG语义搜索"""
    conn = None
    try:
        conn = get_db_conn()
        
        # 1. 生成查询向量
        query_embedding = ocr_service.generate_embedding(query)
        
        # 2. 并行执行语义搜索和关键词搜索
        semantic_results = semantic_search_chunks(conn, query_embedding, document_id, top_k)
        keyword_results = keyword_search_chunks(conn, query, document_id, top_k)
        
        # 3. 使用RRF算法融合结果
        fused_results = _fuse_results_with_rrf(semantic_results, keyword_results, top_k)
        
        # 4. 使用reranker重新排序
        reranked_contents = [item['content'] for item in fused_results]
        reranked_pairs = ocr_service.rerank_results(query, reranked_contents)
        
        # 重构结果，包含坐标信息
        final_results = []
        for content, score in reranked_pairs[:top_k]:
            # 找到对应的块信息
            for item in fused_results:
                if item['content'] == content:
                    final_results.append({
                        **item,
                        'confidence_score': score
                    })
                    break
        
        # 5. 生成AI回复和引用
        context_str = "\n".join([item['content'] for item in final_results])
        system_prompt = f"""
        你是一个专业的AI助教，能够基于提供的文档内容准确回答学生的问题。
        以下是相关的文档片段：
        {context_str}
        
        请根据以上内容回答学生的问题，并在答案中适当标注信息来源。
        """
        
        answer = ask_deepseek(
            user_query=query,
            system_prompt=system_prompt,
            history=[],
            temperature=0.7
        )
        
        # 转换为前端需要的格式
        references = []
        for item in final_results:
            references.append({
                'chunk_id': str(item['id']),
                'content': item['content'],
                'page_number': item['page_number'],
                'coordinates': item['normalized_coords'],
                'confidence_score': item.get('confidence_score', 0.0)
            })
        
        return {
            'answer': answer,
            'references': references
        }
        
    except Exception as e:
        logger.error(f"RAG search failed: {e}")
        raise
    finally:
        if conn:
            conn.close()

def _fuse_results_with_rrF(semantic_results: List[Dict], keyword_results: List[Dict], top_k: int) -> List[Dict]:
    """使用RRF (Reciprocal Rank Fusion) 算法融合搜索结果"""
    # 创建ID到结果的映射
    semantic_map = {item['id']: item for item in semantic_results}
    keyword_map = {item['id']: item for item in keyword_results}
    
    # 合并所有唯一ID
    all_ids = set(semantic_map.keys()) | set(keyword_map.keys())
    
    # 计算RRF分数
    rrf_scores = {}
    k_const = 60  # RRF常数
    
    # 计算语义搜索的RRF分数
    for i, item in enumerate(semantic_results):
        rrf_scores[item['id']] = 1.0 / (k_const + i)
    
    # 计算关键词搜索的RRF分数
    for i, item in enumerate(keyword_results):
        score = rrf_scores.get(item['id'], 0.0)
        score += 1.0 / (k_const + i)
        rrf_scores[item['id']] = score
    
    # 合并结果并按RRF分数排序
    combined_results = []
    for item_id in all_ids:
        semantic_item = semantic_map.get(item_id)
        keyword_item = keyword_map.get(item_id)
        
        # 使用分数最高的结果，但保留两种搜索的信息
        if semantic_item and keyword_item:
            combined_item = {**semantic_item, **keyword_item}
        elif semantic_item:
            combined_item = semantic_item
        else:
            combined_item = keyword_item
            
        combined_item['rrf_score'] = rrf_scores[item_id]
        combined_results.append(combined_item)
    
    # 按RRF分数降序排列
    combined_results.sort(key=lambda x: x['rrf_score'], reverse=True)
    
    return combined_results[:top_k] 