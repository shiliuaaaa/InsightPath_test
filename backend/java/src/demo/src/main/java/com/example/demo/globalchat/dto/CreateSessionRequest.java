package com.example.demo.globalchat.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class CreateSessionRequest {

    private String title;

    @JsonProperty("initial_title")
    private String initialTitle;
}

