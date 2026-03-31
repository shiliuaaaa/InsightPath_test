package com.example.demo.globalchat.controller;

import com.example.demo.auth.entity.User;
import com.example.demo.auth.filter.JwtAuthFilter;
import com.example.demo.auth.repository.UserRepository;
import com.example.demo.dto.ApiResponse;
import com.example.demo.globalchat.dto.CreateSessionRequest;
import com.example.demo.globalchat.dto.GlobalChatMessageResponse;
import com.example.demo.globalchat.dto.GlobalChatSessionResponse;
import com.example.demo.globalchat.dto.SendGlobalMessageRequest;
import com.example.demo.globalchat.service.GlobalChatService;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/global-chat")
public class GlobalChatController {

    private final GlobalChatService globalChatService;
    private final UserRepository userRepository;

    public GlobalChatController(GlobalChatService globalChatService,
                                UserRepository userRepository) {
        this.globalChatService = globalChatService;
        this.userRepository = userRepository;
    }

    @PostMapping("/sessions")
    public ResponseEntity<ApiResponse<GlobalChatSessionResponse>> createSession(@RequestBody(required = false) CreateSessionRequest body,
                                                                 HttpServletRequest request) {
        User user = getCurrentUser(request);
        String title = null;
        if (body != null) {
            title = (body.getTitle() != null && !body.getTitle().isBlank())
                    ? body.getTitle()
                    : body.getInitialTitle();
        }
        GlobalChatSessionResponse response = globalChatService.createSession(user.getId(), title);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(new ApiResponse<>(201, "创建成功", response));
    }

    @GetMapping("/sessions")
    public ApiResponse<List<GlobalChatSessionResponse>> listSessions(HttpServletRequest request) {
        User user = getCurrentUser(request);
        List<GlobalChatSessionResponse> sessions = globalChatService.listUserSessions(user.getId());
        return ApiResponse.success("获取成功", sessions);
    }

    @GetMapping("/sessions/{sessionId}/messages")
    public ApiResponse<List<GlobalChatMessageResponse>> getSessionMessages(@PathVariable Long sessionId,
                                                                            HttpServletRequest request) {
        User user = getCurrentUser(request);
        List<GlobalChatMessageResponse> messages = globalChatService.getSessionMessages(user.getId(), sessionId);
        return ApiResponse.success("获取成功", messages);
    }

    @PostMapping("/message")
    public ApiResponse<Map<String, Object>> sendMessage(@RequestBody SendGlobalMessageRequest body,
                                                         HttpServletRequest request) {
        User user = getCurrentUser(request);
        if (body == null || body.getSessionId() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "sessionId 不能为空");
        }
        String reply = globalChatService.sendMessage(
                user.getId(),
                body.getSessionId(),
                body.getContent(),
                Boolean.TRUE.equals(body.getEnableWebSearch()),
                body.getFileContext()
        );
        Map<String, Object> data = Map.of(
                "session_id", body.getSessionId(),
                "reply", reply
        );
        return ApiResponse.success("回复成功", data);
    }

    private User getCurrentUser(HttpServletRequest request) {
        Claims claims = (Claims) request.getAttribute(JwtAuthFilter.CLAIMS_ATTRIBUTE);
        if (claims == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "未认证");
        }
        Long userId = extractUserId(claims.get("user_id"));
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "用户不存在"));
    }

    private Long extractUserId(Object rawUserId) {
        if (rawUserId instanceof Number number) {
            return number.longValue();
        }
        if (rawUserId instanceof String text) {
            try {
                return Long.parseLong(text);
            } catch (NumberFormatException ex) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "无效的用户ID");
            }
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "无效的用户ID");
    }
}

