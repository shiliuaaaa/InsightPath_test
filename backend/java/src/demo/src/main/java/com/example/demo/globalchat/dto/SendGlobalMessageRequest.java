package com.example.demo.globalchat.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class SendGlobalMessageRequest {

    @JsonProperty("session_id")
    private Long sessionId;

    private String content;
}

