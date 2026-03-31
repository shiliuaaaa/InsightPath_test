import asyncio
import logging
from typing import List, Dict, Any
import numpy as np
from pydantic import BaseModel
from transformers import AutoModel, AutoTokenizer
import torch
from PIL import Image
import requests
import tempfile
import os
from pathlib import Path

logger = logging.getLogger("AIService")

# 使用Alibaba BGE-M3模型
EMBEDDING_MODEL_NAME = "BAAI/bge-m3"
RERANKER_MODEL_NAME = "BAAI/bge-reranker-v2-m3"

class OCRService:
    def __init__(self):
        self.embedding_model = None
        self.reranker_model = None
        self.tokenizer = None
        self._load_models()
    
    def _load_models(self):
        """加载嵌入和重排序模型"""
        try:
            logger.info("Loading embedding model...")
            self.embedding_model = AutoModel.from_pretrained(EMBEDDING_MODEL_NAME)
            self.tokenizer = AutoTokenizer.from_pretrained(EMBEDDING_MODEL_NAME)
            self.embedding_model.eval()
            
            logger.info("Loading reranker model...")
            self.reranker_model = AutoModel.from_pretrained(RERANKER_MODEL_NAME)
            self.reranker_model.eval()
            
            logger.info("Models loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load models: {e}")
            raise
    
    async def analyze_document(self, file_url: str) -> List[Dict[str, Any]]:
        """分析文档，提取文本和坐标信息"""
        # TODO: 集成MinerU或其他OCR工具
        # 这里先模拟实现，实际需要替换为真正的OCR分析
        logger.info(f"Analyzing document: {file_url}")
        
        # 模拟OCR结果
        # 实际实现中，这里应该调用MinerU进行文档解析
        mock_result = [
            {
                "page_number": 1,
                "content": "这是文档的标题",
                "chunk_type": "title",
                "normalized_coords": [0.1, 0.1, 0.9, 0.15]  # [x0, y0, x1, y1]
            },
            {
                "page_number": 1,
                "content": "这是文档的第一段内容，包含重要的知识点。",
                "chunk_type": "paragraph",
                "normalized_coords": [0.1, 0.2, 0.9, 0.3]
            },
            {
                "page_number": 2,
                "content": "这是第二页的内容，用于演示功能。",
                "chunk_type": "paragraph",
                "normalized_coords": [0.1, 0.1, 0.9, 0.2]
            }
        ]
        
        return mock_result
    
    def generate_embedding(self, text: str) -> List[float]:
        """生成文本的向量表示"""
        if not self.embedding_model:
            raise RuntimeError("Embedding model not loaded")
        
        encoded_input = self.tokenizer(text, padding=True, truncation=True, return_tensors='pt')
        
        with torch.no_grad():
            embeddings = self.embedding_model(**encoded_input).last_hidden_state.mean(dim=1)
            # 归一化向量
            embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
        
        return embeddings[0].tolist()
    
    def batch_generate_embeddings(self, texts: List[str]) -> List[List[float]]:
        """批量生成向量"""
        if not self.embedding_model:
            raise RuntimeError("Embedding model not loaded")
        
        encoded_inputs = self.tokenizer(texts, padding=True, truncation=True, return_tensors='pt')
        
        with torch.no_grad():
            embeddings = self.embedding_model(**encoded_inputs).last_hidden_state.mean(dim=1)
            # 归一化向量
            embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
        
        return embeddings.tolist()
    
    def rerank_results(self, query: str, candidates: List[str]) -> List[tuple[str, float]]:
        """使用重排序模型重新排序结果"""
        if not self.reranker_model:
            raise RuntimeError("Reranker model not loaded")
        
        # 构建查询-候选对
        pairs = [[query, candidate] for candidate in candidates]
        
        encoded_pairs = self.tokenizer(
            pairs,
            padding=True,
            truncation=True,
            return_tensors='pt',
            max_length=512
        )
        
        with torch.no_grad():
            scores = self.reranker_model(**encoded_pairs, return_dict=True).logits.view(-1, len(candidates)).squeeze(0)
            scores = torch.softmax(scores, dim=0).tolist()
        
        # 返回排序后的结果
        scored_pairs = list(zip(candidates, scores))
        scored_pairs.sort(key=lambda x: x[1], reverse=True)
        return scored_pairs

# 全局OCR服务实例
ocr_service = OCRService()