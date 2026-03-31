package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * PUT /api/v1/users/me 响应 DTO
 * 文档要求: id, nickname, school_id, role, updated_at
 */
@Data
public class UpdateUserResponse {
    private Long id;
    private String nickname;
    @JsonProperty("school_id")
    private Long schoolId;
    private String school;
    @JsonProperty("avatar_url")
    private String avatarUrl;
    @JsonProperty("bg_url")
    private String bgUrl;
    private String bio;
    private String role;
    @JsonProperty("updated_at")
    private LocalDateTime updatedAt;
}
