package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class CreateSyllabusKnowledgeRequest {
    private String title;

    @JsonProperty("resource_file_id")
    private Long resourceFileId;
}

