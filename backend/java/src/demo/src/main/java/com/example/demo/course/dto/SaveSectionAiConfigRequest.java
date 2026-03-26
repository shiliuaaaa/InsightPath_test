package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class SaveSectionAiConfigRequest {

    @JsonProperty("page_number")
    private Integer pageNumber;

    private String prompt;

    @JsonProperty("generated_dsl")
    private String generatedDsl;
}

