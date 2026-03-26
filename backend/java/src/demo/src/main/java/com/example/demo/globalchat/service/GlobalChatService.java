package com.example.demo.globalchat.service;

import com.example.demo.globalchat.dto.GlobalChatMessageResponse;
import com.example.demo.globalchat.dto.GlobalChatSessionResponse;
import com.example.demo.globalchat.entity.AiChatMessage;
import com.example.demo.globalchat.entity.AiChatSession;
import com.example.demo.globalchat.repository.AiChatSessionRepository;
import com.example.demo.globalchat.repository.GlobalAiChatMessageRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class GlobalChatService {

    private final AiChatSessionRepository sessionRepository;
    private final GlobalAiChatMessageRepository messageRepository;
    private final RestTemplate restTemplate;
    private final String pythonAiUrl;

    public GlobalChatService(AiChatSessionRepository sessionRepository,
                             GlobalAiChatMessageRepository messageRepository,
                             @Value("${python.ai.url:http://localhost:5001/api/v1/chat/global}") String pythonAiUrl) {
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
        this.restTemplate = new RestTemplate();
        this.pythonAiUrl = pythonAiUrl;
    }

    public GlobalChatSessionResponse createSession(Long userId, String title) {
        AiChatSession session = new AiChatSession();
        session.setUserId(userId);
        session.setTitle(resolveTitle(title));
        AiChatSession saved = sessionRepository.save(session);
        return toSessionResponse(saved);
    }

    public List<GlobalChatSessionResponse> listUserSessions(Long userId) {
        List<AiChatSession> sessions = sessionRepository.findByUserIdOrderByUpdatedAtDesc(userId);
        List<GlobalChatSessionResponse> response = new ArrayList<>();
        for (AiChatSession session : sessions) {
            response.add(toSessionResponse(session));
        }
        return response;
    }

    public List<GlobalChatMessageResponse> getSessionMessages(Long userId, Long sessionId) {
        AiChatSession session = requireOwnedSession(userId, sessionId);
        List<AiChatMessage> messages = messageRepository.findBySessionIdOrderByCreatedAtAsc(session.getId());
        List<GlobalChatMessageResponse> response = new ArrayList<>();
        for (AiChatMessage message : messages) {
            response.add(toMessageResponse(message));
        }
        return response;
    }

    public String sendMessage(Long userId, Long sessionId, String userContent) {
        if (userContent == null || userContent.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "消息内容不能为空");
        }

        AiChatSession session = requireOwnedSession(userId, sessionId);

        AiChatMessage userMessage = new AiChatMessage();
        userMessage.setSessionId(session.getId());
        userMessage.setRole("user");
        userMessage.setContent(userContent.trim());
        messageRepository.save(userMessage);

        List<AiChatMessage> historyMessages = messageRepository.findBySessionIdOrderByCreatedAtAsc(session.getId());
        List<Map<String, String>> history = new ArrayList<>();
        for (AiChatMessage message : historyMessages) {
            Map<String, String> item = new HashMap<>();
            item.put("role", message.getRole());
            item.put("content", message.getContent());
            history.add(item);
        }

        String assistantReply = callPythonAi(history, session.getId(), userId);

        AiChatMessage assistantMessage = new AiChatMessage();
        assistantMessage.setSessionId(session.getId());
        assistantMessage.setRole("assistant");
        assistantMessage.setContent(assistantReply);
        messageRepository.save(assistantMessage);

        session.setUpdatedAt(java.time.LocalDateTime.now());
        sessionRepository.save(session);

        return assistantReply;
    }

    private String callPythonAi(List<Map<String, String>> history, Long sessionId, Long userId) {
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("session_id", sessionId);
        requestBody.put("user_id", userId);
        requestBody.put("messages", history);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(pythonAiUrl, entity, Map.class);
            if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
                throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "AI 服务响应异常");
            }

            Map<String, Object> body = response.getBody();
            Object dataObj = body.get("data");
            if (dataObj instanceof Map<?, ?> dataMap) {
                Object replyObj = dataMap.get("reply");
                if (replyObj instanceof String reply && !reply.isBlank()) {
                    return reply;
                }
            }
            Object replyObj = body.get("reply");
            if (replyObj instanceof String reply && !reply.isBlank()) {
                return reply;
            }
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "AI 服务返回内容为空");
        } catch (ResponseStatusException ex) {
            throw ex;
        } catch (Exception ex) {
            return "这是假数据回复";
        }
    }

    private AiChatSession requireOwnedSession(Long userId, Long sessionId) {
        AiChatSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "会话不存在"));
        if (!session.getUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权限访问该会话");
        }
        return session;
    }

    private String resolveTitle(String title) {
        if (title == null || title.isBlank()) {
            return "新会话";
        }
        String value = title.trim();
        return value.length() > 255 ? value.substring(0, 255) : value;
    }

    private GlobalChatSessionResponse toSessionResponse(AiChatSession session) {
        GlobalChatSessionResponse response = new GlobalChatSessionResponse();
        response.setId(session.getId());
        response.setTitle(session.getTitle());
        response.setCreatedAt(session.getCreatedAt());
        response.setUpdatedAt(session.getUpdatedAt());
        return response;
    }

    private GlobalChatMessageResponse toMessageResponse(AiChatMessage message) {
        GlobalChatMessageResponse response = new GlobalChatMessageResponse();
        response.setId(message.getId());
        response.setSessionId(message.getSessionId());
        response.setRole(message.getRole());
        response.setContent(message.getContent());
        response.setCreatedAt(message.getCreatedAt());
        return response;
    }
}

