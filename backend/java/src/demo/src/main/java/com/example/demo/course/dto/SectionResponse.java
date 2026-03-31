package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

/**
 * 栏目列表响应 DTO — 仅返回文档要求的字段。
 * 对应文档：GET /api/v1/courses/{course_id}/sections
 */
@Data
public class SectionResponse {
    private Long id;
    private String title;
    private String type;   // DISPLAY / STORAGE / AI
    private int order;

    @JsonProperty("is_hidden")
    private Boolean isHidden;
}
