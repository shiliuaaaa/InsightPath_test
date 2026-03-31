package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class RagSearchRequest {
    private String query;
    @JsonProperty("document_id")
    private Long documentId;
    @JsonProperty("top_k")
    private Integer topK; // 可选，默认为5
}