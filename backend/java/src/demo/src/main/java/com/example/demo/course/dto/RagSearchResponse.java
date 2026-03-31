package com.example.demo.course.dto;

import lombok.Data;

import java.util.List;
import java.util.Map;

@Data
public class RagSearchResponse {
    // 映射到 Python 返回的 data.answer
    private String answer;

    // 映射到 Python 返回的 data.references
    private List<SearchReference> references;

    private Boolean success;
    private String message;
}
