package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class EnrollRequest {
    @JsonProperty("apply_reason")
    private String applyReason;
}
