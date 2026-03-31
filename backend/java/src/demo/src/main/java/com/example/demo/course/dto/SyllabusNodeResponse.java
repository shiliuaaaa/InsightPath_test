package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

import java.util.ArrayList;
import java.util.List;

@Data
public class SyllabusNodeResponse {
    private Long id;

    @JsonProperty("parent_id")
    private Long parentId;

    private String type;
    private String title;

    @JsonProperty("resource_file_id")
    private Long resourceFileId;

    @JsonProperty("resource_name")
    private String resourceName;

    @JsonProperty("resource_url")
    private String resourceUrl;

    @JsonProperty("resource_pdf_url")
    private String resourcePdfUrl;

    @JsonProperty("resource_extension")
    private String resourceExtension;

    private String question;
    private List<QuizOptionDto> options = new ArrayList<>();
    private String answer;

    private List<SyllabusNodeResponse> children = new ArrayList<>();
}

