package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class AiConfigRequest {
    @JsonProperty("welcome_message")
    private String welcomeMessage;
    @JsonProperty("system_prompt")
    private String systemPrompt;
}
