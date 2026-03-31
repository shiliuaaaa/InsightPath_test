package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class UpdateUserRequest {
    private String nickname;
    @JsonProperty("school_id")
    private Long schoolId;
    private String school;
    @JsonProperty("avatar_url")
    private String avatarUrl;
    @JsonProperty("bg_url")
    private String bgUrl;
    private String bio;
}
