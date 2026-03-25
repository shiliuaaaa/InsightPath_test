package com.example.demo.course.service;

import com.example.demo.course.entity.AiChatMessage;
import com.example.demo.course.repository.AiChatMessageRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashMap;
import java.util.Map;

@Service
public class AiChatService {

    private final AiChatMessageRepository chatMessageRepository;
    private final RestTemplate restTemplate;
    private final String pythonServiceUrl;

    public AiChatService(AiChatMessageRepository chatMessageRepository,
                          @Value("${app.ai.python-service-url:http://python:5000}") String pythonServiceUrl) {
        this.chatMessageRepository = chatMessageRepository;
        this.restTemplate = new RestTemplate();
        this.pythonServiceUrl = pythonServiceUrl;
    }

    /**
     * 发送消息给 AI 并返回回复。
     * <p>
     * 注意：消息的持久化由 Python 服务负责（save_message），
     * Java 端不再重复写入 ai_chat_messages 表。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> chat(Long sectionId, Long userId, String message) {
        // 调用 Python 服务
        String url = pythonServiceUrl + "/internal/ai/chat";
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("section_id", sectionId);
        requestBody.put("user_id", userId);
        requestBody.put("content", message);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(url, entity, Map.class);

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                Map<String, Object> body = response.getBody();
                Map<String, Object> data = (Map<String, Object>) body.get("data");
                String reply = data != null ? (String) data.get("reply") : "AI 暂时无法回答";

                // 从数据库取最新一条 ASSISTANT 消息作为 chat_id（Python 已写入）
                Long chatId = null;
                var latest = chatMessageRepository
                        .findBySectionIdAndUserIdOrderByCreatedAtDesc(sectionId, userId, PageRequest.of(0, 1));
                if (!latest.isEmpty()) {
                    AiChatMessage latestMsg = latest.getContent().get(0);
                    if (latestMsg.getRole() == AiChatMessage.MessageRole.ASSISTANT) {
                        chatId = latestMsg.getId();
                    }
                }

                Map<String, Object> result = new HashMap<>();
                result.put("chat_id", chatId);
                result.put("reply", reply);
                result.put("created_at", java.time.LocalDateTime.now());
                return result;
            } else {
                throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "AI服务响应异常");
            }
        } catch (ResponseStatusException e) {
            throw e;
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "AI服务暂不可用: " + e.getMessage());
        }
    }
}
