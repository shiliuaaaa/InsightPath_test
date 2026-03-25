package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class UpdateUserRequest {
    private String nickname;
    @JsonProperty("school_id")
    private Long schoolId;
}
