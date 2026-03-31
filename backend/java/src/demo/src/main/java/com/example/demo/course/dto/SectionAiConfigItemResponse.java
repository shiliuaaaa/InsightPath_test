package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class SectionAiConfigItemResponse {
    private Long id;

    @JsonProperty("section_id")
    private Long sectionId;

    @JsonProperty("page_number")
    private Integer pageNumber;

    private String prompt;

    @JsonProperty("generated_dsl")
    private String generatedDsl;

    @JsonProperty("updated_at")
    private LocalDateTime updatedAt;
}

