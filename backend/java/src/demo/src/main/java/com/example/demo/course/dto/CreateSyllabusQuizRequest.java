package com.example.demo.course.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

import java.util.List;

@Data
public class CreateSyllabusQuizRequest {

    @JsonProperty("quiz_type")
    private String quizType;

    private String question;

    private List<QuizOptionDto> options;

    private String answer;
}

