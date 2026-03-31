package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

import java.util.List;

@Data
public class UpdateSyllabusNodeRequest {
    private String title;

    @JsonProperty("resource_file_id")
    private Long resourceFileId;

    private String question;

    private List<QuizOptionDto> options;

    private String answer;
}

