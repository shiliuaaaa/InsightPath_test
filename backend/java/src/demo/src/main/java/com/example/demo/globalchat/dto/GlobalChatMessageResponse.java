package com.example.demo.globalchat.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class GlobalChatMessageResponse {

    private Long id;

    @JsonProperty("session_id")
    private Long sessionId;

    private String role;

    private String content;

    @JsonProperty("created_at")
    private LocalDateTime createdAt;
}

