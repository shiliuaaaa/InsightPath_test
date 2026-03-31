package com.example.demo.course.service;

import com.example.demo.course.dto.RagSearchRequest;
import com.example.demo.course.dto.RagSearchResponse;
import com.example.demo.course.dto.SearchReference;
import com.example.demo.course.entity.CourseFile;
import com.example.demo.course.repository.CourseFileRepository;
import com.example.demo.course.repository.DocumentTextChunkRepository;
import com.example.demo.dto.ApiResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@Transactional
public class RagService {

    @Autowired
    private RestTemplate restTemplate;

    @Autowired
    private CourseFileRepository courseFileRepository;

    @Autowired
    private DocumentTextChunkRepository documentTextChunkRepository;

    private final String PYTHON_API_URL = System.getenv("PYTHON_API_URL");

    public RagSearchResponse performSemanticSearch(String query, Long documentId, Integer topK) {
        if (topK == null) {
            topK = 5;
        }

        Map<String, Object> pythonRequest = new HashMap<>();
        pythonRequest.put("query", query);
        pythonRequest.put("document_id", documentId);
        pythonRequest.put("top_k", topK);

        org.springframework.http.HttpHeaders headers = new org.springframework.http.HttpHeaders();
        headers.add("Content-Type", "application/json");
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(pythonRequest, headers);

        try {
            ResponseEntity<Map> response = restTemplate.exchange(
                    PYTHON_API_URL + "/api/v1/rag/search",
                    HttpMethod.POST,
                    entity,
                    Map.class
            );

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                Map<String, Object> responseBody = response.getBody();
                
                Integer code = (Integer) responseBody.get("code");
                String message = (String) responseBody.get("message");
                Map<String, Object> data = (Map<String, Object>) responseBody.get("data");

                if (code != null && code == 200 && data != null) {
                    // 从 data 中提取具体内容
                    String answer = (String) data.get("answer");
                    List<Map<String, Object>> refs = (List<Map<String, Object>>) data.get("references");

                    // 构建 Java DTO
                    RagSearchResponse ragResponse = new RagSearchResponse();
                    ragResponse.setAnswer(answer);
                    
                    // 将 List<Map> 转换为 List<SearchReference>
                    if (refs != null) {
                        List<SearchReference> searchRefs = refs.stream()
                                .map(rawRef -> {
                                    SearchReference ref = new SearchReference();
                                    ref.setTitle((String) rawRef.get("title"));
                                    ref.setSnippet((String) rawRef.get("snippet"));
                                    ref.setLink((String) rawRef.get("link"));
                                    return ref;
                                })
                                .toList(); // Java 16+
                        ragResponse.setReferences(searchRefs);
                    }

                    // 设置顶层消息和成功状态
                    ragResponse.setMessage(message);
                    ragResponse.setSuccess(true);

                    return ragResponse;
                } else {
                    // Python 服务返回了非成功的 code 或 data 为空
                    String errorMsg = (String) data.get("message"); // Python 可能在 data 中包含错误信息
                    if (errorMsg == null) errorMsg = "Python service returned error code: " + code;
                    throw new RuntimeException(errorMsg);
                }
            } else {
                throw new RuntimeException("Python service returned an error: " + response.getStatusCodeValue());
            }
        } catch (Exception e) {
            e.printStackTrace();
            throw new RuntimeException("Failed to perform semantic search via Python service: " + e.getMessage());
        }
    }
}